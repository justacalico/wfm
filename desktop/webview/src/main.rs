#[cfg(any(
    target_os = "linux",
    target_os = "dragonfly",
    target_os = "freebsd",
    target_os = "openbsd",
    target_os = "netbsd"
))]
mod platform {
    use gtk::prelude::*;
    use wry::WebViewBuilderExtUnix;

    pub fn run(url: String, title: String) {
        gtk::init().expect("gtk init");
        let window = gtk::Window::new(gtk::WindowType::Toplevel);
        window.set_title(&title);
        window.set_default_size(1280, 800);
        window.show_all();
        let _webview = wry::WebViewBuilder::new()
            .with_url(&url)
            .build_gtk(&window)
            .expect("webview");
        window.show_all();
        gtk::main();
    }
}

#[cfg(not(any(
    target_os = "linux",
    target_os = "dragonfly",
    target_os = "freebsd",
    target_os = "openbsd",
    target_os = "netbsd"
)))]
mod platform {
    use tao::event::{Event, WindowEvent};
    use tao::event_loop::{ControlFlow, EventLoop};
    use tao::window::WindowBuilder;
    use wry::WebViewBuilder;

    pub fn run(url: String, title: String) {
        let event_loop = EventLoop::new();
        let window = WindowBuilder::new()
            .with_title(title)
            .with_inner_size(tao::dpi::LogicalSize::new(1280.0, 800.0))
            .build(&event_loop)
            .expect("window");
        let _webview = WebViewBuilder::new()
            .with_url(&url)
            .build(&window)
            .expect("webview");
        event_loop.run(move |event, _, control_flow| {
            *control_flow = ControlFlow::Wait;
            if let Event::WindowEvent {
                event: WindowEvent::CloseRequested,
                ..
            } = event
            {
                *control_flow = ControlFlow::Exit;
            }
        });
    }
}

fn main() {
    let mut args = std::env::args().skip(1);
    let mut url = String::new();
    let mut title = String::from("WFM");
    while let Some(a) = args.next() {
        match a.as_str() {
            "--title" => {
                if let Some(t) = args.next() {
                    title = t;
                }
            }
            _ => url = a,
        }
    }
    if url.is_empty() {
        eprintln!("usage: wfm-webview <url> [--title <title>]");
        std::process::exit(2);
    }
    platform::run(url, title);
}
