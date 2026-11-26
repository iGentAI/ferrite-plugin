#![forbid(unsafe_code)]
//! The page-app starter: a complete, deployed-and-verified Ferrite app that
//! serves one polished page and records form posts in the app's store. It is a
//! live poll as shipped; adapt it to the request (an RSVP list, a sign-up
//! sheet, a guestbook, a scoreboard, a dashboard) by changing the constants,
//! `handle` and `render`. The serve loop, `html`, the CSS theme and the
//! store calls are the parts to keep.
//!
//! `GET /` renders the page; `POST /vote` with `choice=<id>` records a vote
//! (once per request, by its idempotency key) and redirects back to `/`.
//! Store API used here: `get(key)`, `add(key, n)` (atomic counter),
//! `put_if_version(key, value, None)` (create-if-absent). Escape any text a
//! visitor typed with `escape` before putting it in HTML.
//! Random IDs/tokens: `ferrite_app::crypto` has no `random_*` on Ferrite Cloud;
//! derive 32 CSPRNG bytes with `hmac_sha256(&Ed25519SigningKey::generate_pkcs8(), label)`
//! or add the `sha256-hmac` package (`crate::crypto::random_bytes` / `random_token`).

use std::time::Duration;

use ferrite_app::client::StoreClusterClient;
use ferrite_app::{app_main, rt, serde_json, AppContext, FerriteApp, IngressReply, IngressRequest};

const QUESTION: &str = "What should Claude build next?";
const OPTIONS: [(&str, &str); 4] = [
    ("game", "A browser game"),
    ("devtool", "A developer tool"),
    ("agent", "A personal AI agent"),
    ("art", "A generative art studio"),
];

struct App;

impl FerriteApp for App {
    fn run(ctx: AppContext) -> impl std::future::Future<Output = std::io::Result<()>> + Send {
        serve(ctx)
    }
}

async fn serve(ctx: AppContext) -> std::io::Result<()> {
    let mut requests = ctx.queue("requests")?;
    let mut votes = ctx.store("data")?;
    loop {
        let lease = match requests.poll_wait(1_000).await {
            Ok(Some(l)) => l,
            Ok(None) => continue,
            Err(_) => {
                rt::time::sleep(Duration::from_millis(200)).await;
                continue;
            }
        };
        let Ok(req) = serde_json::from_slice::<IngressRequest>(&lease.payload) else {
            let _ = requests.ack(lease.token).await;
            continue;
        };
        let reply = match handle(&mut votes, &req).await {
            Ok(r) => r,
            Err(_) => html(&req, 503, "<p>Store unavailable, try again.</p>".into()),
        };
        if let Ok(mut out) = ctx.reply_to_queue(&req.reply_to).await {
            if let Ok(payload) = serde_json::to_vec(&reply) {
                let _ = out.publish(&payload).await;
            }
        }
        let _ = requests.ack(lease.token).await;
    }
}

async fn handle(votes: &mut StoreClusterClient, req: &IngressRequest) -> std::io::Result<IngressReply> {
    let path = req.path.split('?').next().unwrap_or("/");
    match (req.method.as_str(), path) {
        ("GET", "/") => {
            let mut counts = [0u64; 4];
            for (i, (id, _)) in OPTIONS.iter().enumerate() {
                if let Some(v) = votes.get(format!("count/{id}").as_bytes()).await? {
                    counts[i] = String::from_utf8_lossy(&v).parse::<i64>().unwrap_or(0).max(0) as u64;
                }
            }
            Ok(html(req, 200, render(&counts)))
        }
        ("POST", "/vote") => {
            let Some(id) = parse_choice(&req.body) else {
                return Ok(html(req, 400, "<p>Unknown option. <a href=\"/\">Back</a></p>".into()));
            };
            // At-least-once delivery: count each request once by its idempotency key.
            let seen = format!("seen/{}", req.idempotency_key);
            if votes.put_if_version(seen.as_bytes(), b"1", None).await?.is_ok() {
                votes.add(format!("count/{id}").as_bytes(), 1).await?;
            }
            let mut r = IngressReply::to(req, 303, b"<meta http-equiv=\"refresh\" content=\"0;url=/\">".to_vec());
            r.headers.push(("location".into(), "/".into()));
            r.headers.push(("content-type".into(), "text/html; charset=utf-8".into()));
            Ok(r)
        }
        _ => Ok(html(req, 404, "<p>Not found. <a href=\"/\">Back</a></p>".into())),
    }
}

/// HTML-escapes visitor-supplied text.
fn escape(s: &str) -> String {
    s.replace('&', "&amp;").replace('<', "&lt;").replace('>', "&gt;").replace('"', "&quot;").replace('\'', "&#39;")
}

fn html(req: &IngressRequest, status: u16, body: String) -> IngressReply {
    let mut r = IngressReply::to(req, status, body.into_bytes());
    r.headers.push(("content-type".into(), "text/html; charset=utf-8".into()));
    r.headers.push(("cache-control".into(), "no-store".into()));
    r
}

/// The option id from a urlencoded form body (`choice=<id>`), if it names a known option.
fn parse_choice(body: &[u8]) -> Option<&'static str> {
    let body = std::str::from_utf8(body).ok()?;
    let value = body.split('&').find_map(|kv| kv.strip_prefix("choice="))?;
    OPTIONS.iter().map(|(id, _)| *id).find(|id| *id == value)
}

/// Whole-number percentage of `n` out of `total`, rounded half up; 0 when nobody has voted.
fn percent(n: u64, total: u64) -> u64 {
    if total == 0 { 0 } else { (n * 200 + total) / (total * 2) }
}

fn render(counts: &[u64; 4]) -> String {
    let total: u64 = counts.iter().sum();
    let mut buttons = String::new();
    let mut bars = String::new();
    for (i, (id, label)) in OPTIONS.iter().enumerate() {
        let p = percent(counts[i], total);
        buttons.push_str(&format!(
            "<button class=\"btn\" type=\"submit\" name=\"choice\" value=\"{id}\">{label}</button>"
        ));
        bars.push_str(&format!(
            "<div class=\"row\"><div class=\"lbl\"><span>{label}</span><span class=\"muted\">{c} &middot; {p}%</span></div>\
             <div class=\"track\"><div class=\"fill\" style=\"width:{p}%\"></div></div></div>",
            c = counts[i]
        ));
    }
    let noun = if total == 1 { "vote" } else { "votes" };
    format!(
        "<!doctype html><html lang=\"en\"><head><meta charset=\"utf-8\">\
<meta name=\"viewport\" content=\"width=device-width,initial-scale=1\"><title>{QUESTION}</title><style>{CSS}</style></head><body><main>\
<section class=\"card\"><h1>{QUESTION}</h1><p class=\"muted\">Pick one. Results update as votes come in.</p>\
<form method=\"post\" action=\"/vote\" class=\"grid\">{buttons}</form></section>\
<section class=\"card\"><div class=\"head\"><h2>Results</h2><span class=\"badge\">{total} {noun}</span></div>{bars}</section>\
</main></body></html>"
    )
}

const CSS: &str = "@import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600&display=swap');\
*{box-sizing:border-box}body{margin:0;min-height:100vh;background:#fafafa;color:#09090b;\
font-family:Inter,ui-sans-serif,system-ui,-apple-system,sans-serif;-webkit-font-smoothing:antialiased}\
main{max-width:36rem;margin:0 auto;padding:3rem 1rem;display:grid;gap:1.5rem}\
.card{background:#fff;border:1px solid #e4e4e7;border-radius:.75rem;padding:1.5rem;box-shadow:0 1px 3px 0 rgb(0 0 0/.1),0 1px 2px -1px rgb(0 0 0/.1)}\
h1{font-size:1.5rem;font-weight:600;letter-spacing:-.025em;margin:0 0 .375rem}h2{font-size:1.125rem;font-weight:600;margin:0}\
.muted{color:#71717a;font-size:.875rem;margin:0}.grid{display:grid;grid-template-columns:1fr 1fr;gap:.75rem;margin-top:1.25rem}\
.btn{font:inherit;font-size:.875rem;font-weight:500;height:2.75rem;padding:0 1rem;border-radius:.5rem;border:1px solid #e4e4e7;\
background:#fff;color:#09090b;cursor:pointer;box-shadow:0 1px 2px 0 rgb(0 0 0/.05);transition:background .15s}\
.btn:hover{background:#f4f4f5}.btn:focus-visible{outline:2px solid #a1a1aa;outline-offset:2px}\
.head{display:flex;justify-content:space-between;align-items:center;margin-bottom:1rem}\
.badge{font-size:.75rem;font-weight:600;padding:.125rem .625rem;border-radius:9999px;background:#18181b;color:#fafafa}\
.row{margin-top:.875rem}.lbl{display:flex;justify-content:space-between;font-size:.875rem;font-weight:500;margin-bottom:.375rem}\
.track{height:.5rem;border-radius:9999px;background:#f4f4f5;overflow:hidden}.fill{height:100%;background:#18181b;border-radius:9999px}\
@media(max-width:480px){.grid{grid-template-columns:1fr}}";

fn main() {
    app_main::<App>()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn percentages() {
        assert_eq!(percent(0, 0), 0);
        assert_eq!(percent(1, 3), 33);
        assert_eq!(percent(2, 3), 67);
        assert_eq!(percent(1, 8), 13);
        assert_eq!(percent(5, 5), 100);
    }

    #[test]
    fn escapes() {
        assert_eq!(escape("<a href=\"x\">&'"), "&lt;a href=&quot;x&quot;&gt;&amp;&#39;");
    }

    #[test]
    fn choices() {
        assert_eq!(parse_choice(b"choice=agent"), Some("agent"));
        assert_eq!(parse_choice(b"x=1&choice=art"), Some("art"));
        assert_eq!(parse_choice(b"choice=nope"), None);
        assert_eq!(parse_choice(b""), None);
    }
}
