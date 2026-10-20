use image::imageops::FilterType;
use image::{GenericImageView, RgbaImage};
use std::path::{Path, PathBuf};

const ALPHA_MIN: u8 = 24;

fn bands(filled: &[bool], min_len: usize, min_gap: usize) -> Vec<(usize, usize)> {
    let mut raw: Vec<(usize, usize)> = Vec::new();
    let mut start: Option<usize> = None;
    for (i, &f) in filled.iter().enumerate() {
        match (f, start) {
            (true, None) => start = Some(i),
            (false, Some(s)) => {
                raw.push((s, i));
                start = None;
            }
            _ => {}
        }
    }
    if let Some(s) = start {
        raw.push((s, filled.len()));
    }
    let mut merged: Vec<(usize, usize)> = Vec::new();
    for b in raw {
        if let Some(last) = merged.last_mut() {
            if b.0 - last.1 < min_gap {
                last.1 = b.1;
                continue;
            }
        }
        merged.push(b);
    }
    merged.into_iter().filter(|b| b.1 - b.0 >= min_len).collect()
}

fn rects(img: &RgbaImage, x0: u32, y0: u32, w: u32, h: u32) -> Vec<(u32, u32, u32, u32)> {
    let rows: Vec<bool> = (y0..y0 + h)
        .map(|y| (x0..x0 + w).any(|x| img.get_pixel(x, y)[3] > ALPHA_MIN))
        .collect();
    let mut out = Vec::new();
    for (ry0, ry1) in bands(&rows, (h as usize) / 14, 3) {
        let cols: Vec<bool> = (x0..x0 + w)
            .map(|x| (ry0..ry1).any(|y| img.get_pixel(x, y0 + y as u32)[3] > ALPHA_MIN))
            .collect();
        for (cx0, cx1) in bands(&cols, (w as usize) / 14, 3) {
            let cx0 = x0 + cx0 as u32;
            let cx1 = x0 + cx1 as u32;
            let tight: Vec<bool> = (y0 + ry0 as u32..y0 + ry1 as u32)
                .map(|y| (cx0..cx1).any(|x| img.get_pixel(x, y)[3] > ALPHA_MIN))
                .collect();
            let first = tight.iter().position(|&f| f).unwrap_or(0) as u32;
            let last = tight.iter().rposition(|&f| f).unwrap_or(0) as u32;
            out.push((cx0, y0 + ry0 as u32 + first, cx1 - cx0, last - first + 1));
        }
    }
    out
}

fn probe(assets: &Path, out: &Path) {
    let preview = out.join("preview");
    let _ = std::fs::create_dir_all(&preview);
    let mut entries: Vec<PathBuf> = std::fs::read_dir(assets)
        .map(|d| d.filter_map(|e| e.ok().map(|e| e.path())).collect())
        .unwrap_or_default();
    entries.sort();
    for path in entries {
        let Ok(dynimg) = image::open(&path) else { continue };
        let (w, h) = dynimg.dimensions();
        let img = dynimg.to_rgba8();
        let transparent = img.pixels().filter(|p| p[3] < ALPHA_MIN).count();
        let name = path.file_stem().map(|s| s.to_string_lossy().to_string()).unwrap_or_default();
        println!(
            "{name}: {w}x{h} alpha={:?} transparent={:.1}%",
            dynimg.color(),
            transparent as f64 * 100.0 / (w * h) as f64
        );
        if transparent == 0 {
            continue;
        }
        for (i, (x, y, rw, rh)) in rects(&img, 0, 0, w, h).into_iter().enumerate() {
            println!("    [{i}] x={x} y={y} w={rw} h={rh}");
            let crop = image::imageops::crop_imm(&img, x, y, rw, rh).to_image();
            let _ = crop.save(preview.join(format!("{name}_{i}.png")));
        }
    }
}

fn icons(src: &Path, res: &Path) {
    let Ok(img) = image::open(src) else {
        eprintln!("cannot open {}", src.display());
        return;
    };
    let sizes = [("mdpi", 1.0), ("hdpi", 1.5), ("xhdpi", 2.0), ("xxhdpi", 3.0), ("xxxhdpi", 4.0)];
    for (bucket, density) in sizes {
        let dir = res.join(format!("mipmap-{bucket}"));
        let _ = std::fs::create_dir_all(&dir);
        let _ = std::fs::remove_file(dir.join("ic_launcher_art.png"));

        let legacy = (48.0 * density) as u32;
        let icon = img.resize_exact(legacy, legacy, FilterType::Lanczos3);
        let _ = icon.save(dir.join("ic_launcher.png"));

        // Adaptive layers are 108dp; launchers show the central 72dp and
        // guarantee only the central 66dp, so the art sits at 88dp.
        let canvas = (108.0 * density) as u32;
        let background = img
            .resize_exact(canvas, canvas, FilterType::Triangle)
            .blur(6.0 * density)
            .brighten(-18);
        let _ = background.save(dir.join("ic_launcher_background.png"));

        let art = (88.0 * density) as u32;
        let scaled = img.resize_exact(art, art, FilterType::Lanczos3).to_rgba8();
        let mut foreground = image::RgbaImage::new(canvas, canvas);
        let offset = i64::from((canvas - art) / 2);
        image::imageops::overlay(&mut foreground, &scaled, offset, offset);
        let _ = foreground.save(dir.join("ic_launcher_foreground.png"));
    }
    println!("icons written");
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    match args.get(1).map(String::as_str) {
        Some("probe") if args.len() >= 4 => probe(Path::new(&args[2]), Path::new(&args[3])),
        Some("icons") if args.len() >= 4 => icons(Path::new(&args[2]), Path::new(&args[3])),
        Some("ring") if args.len() >= 6 => {
            let n: Vec<f32> = args[3..6].iter().filter_map(|v| v.parse().ok()).collect();
            if let (Ok(img), [cx, cy, r]) = (image::open(&args[2]), n.as_slice()) {
                let img = img.to_rgba8();
                let mut line = String::new();
                for deg in 0..360 {
                    let a = (deg as f32 - 90.0).to_radians();
                    let x = (cx + r * a.cos()) as u32;
                    let y = (cy + r * a.sin()) as u32;
                    let p = img.get_pixel(x, y);
                    let lum = (p[0] as u32 * 3 + p[1] as u32 * 6 + p[2] as u32) / 10;
                    line.push(match lum {
                        0..=60 => '.',
                        61..=110 => ':',
                        111..=160 => 'o',
                        161..=210 => 'O',
                        _ => '#',
                    });
                    if deg % 60 == 59 {
                        println!("{:>3}: {line}", deg - 59);
                        line.clear();
                    }
                }
            }
        }
        Some("crop") if args.len() >= 8 => {
            let n: Vec<u32> = args[3..7].iter().filter_map(|v| v.parse().ok()).collect();
            if let (Ok(img), [x, y, w, h]) = (image::open(&args[2]), n.as_slice()) {
                let _ = img.crop_imm(*x, *y, *w, *h).save(&args[7]);
            }
        }
        Some("grid") if args.len() >= 4 => {
            if let Ok(img) = image::open(&args[2]) {
                let scale = 900.0 / img.width() as f32;
                let h = (img.height() as f32 * scale) as u32;
                let mut out = img.resize_exact(900, h, FilterType::Triangle).to_rgba8();
                for step in 1..20u32 {
                    let strong = step % 2 == 0;
                    let color = if strong { image::Rgba([255, 0, 255, 255]) } else { image::Rgba([0, 255, 0, 160]) };
                    let x = 900 * step / 20;
                    let y = h * step / 20;
                    for t in 0..h {
                        out.put_pixel(x.min(899), t, color);
                    }
                    for t in 0..900 {
                        out.put_pixel(t, y.min(h - 1), color);
                    }
                }
                println!("{} x {}", img.width(), img.height());
                let _ = out.save(&args[3]);
            }
        }
        _ => eprintln!("usage: sprite_probe probe <dir> <out> | icons <icon> <res>"),
    }
}
