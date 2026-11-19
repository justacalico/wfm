//! Minimal ZIP64 store-only writer: local headers carry the real sizes in a
//! ZIP64 extra field, data descriptors close each file, and a ZIP64 central
//! directory finishes the archive. Sizes are known up front (blob HEAD) so
//! bodies stream once through a crc32 accumulate.

pub struct Rec {
    pub name: String,
    pub crc: u32,
    pub size: u64,
    pub offset: u64,
}

fn w32(v: u32, out: &mut Vec<u8>) {
    out.extend_from_slice(&v.to_le_bytes());
}

fn w16(v: u16, out: &mut Vec<u8>) {
    out.extend_from_slice(&v.to_le_bytes());
}

fn w64(v: u64, out: &mut Vec<u8>) {
    out.extend_from_slice(&v.to_le_bytes());
}

fn put_str(s: &str, out: &mut Vec<u8>) {
    out.extend_from_slice(s.as_bytes());
}

pub fn local_header(name: &str, size: u64) -> Vec<u8> {
    let mut out = Vec::with_capacity(30 + 20 + name.len());
    w32(0x04034b50, &mut out);
    w16(45, &mut out); // version needed: ZIP64
    w16(1 << 3, &mut out); // data descriptor follows
    w16(0, &mut out); // store
    w16(0, &mut out); // mod time
    w16(0, &mut out); // mod date
    w32(0, &mut out); // crc in descriptor
    w32(0xFFFFFFFF, &mut out);
    w32(0xFFFFFFFF, &mut out);
    w16(name.len() as u16, &mut out);
    w16(20, &mut out); // extra len
    put_str(name, &mut out);
    w16(0x0001, &mut out); // ZIP64 extra tag
    w16(16, &mut out);
    w64(size, &mut out);
    w64(size, &mut out);
    out
}

pub fn data_desc(crc: u32, size: u64) -> Vec<u8> {
    let mut out = Vec::with_capacity(24);
    w32(0x08074b50, &mut out);
    w32(crc, &mut out);
    w64(size, &mut out);
    w64(size, &mut out);
    out
}

fn central_header(r: &Rec) -> Vec<u8> {
    let mut out = Vec::with_capacity(46 + 28 + r.name.len());
    w32(0x02014b50, &mut out);
    w16(45, &mut out); // version made by
    w16(45, &mut out); // version needed
    w16(1 << 3, &mut out);
    w16(0, &mut out);
    w16(0, &mut out);
    w16(0, &mut out);
    w32(r.crc, &mut out);
    w32(0xFFFFFFFF, &mut out);
    w32(0xFFFFFFFF, &mut out);
    w16(r.name.len() as u16, &mut out);
    w16(28, &mut out);
    w16(0, &mut out);
    w16(0, &mut out);
    w16(0, &mut out);
    w16(0, &mut out);
    w32(0, &mut out);
    w32(0xFFFFFFFF, &mut out); // local header offset, in extra
    put_str(&r.name, &mut out);
    w16(0x0001, &mut out);
    w16(24, &mut out);
    w64(r.size, &mut out);
    w64(r.size, &mut out);
    w64(r.offset, &mut out);
    out
}

/// Central directory + ZIP64 EOCD + locator + EOCD, `cd_off` = absolute byte
/// offset where the first central header lands.
pub fn end(recs: &[Rec], cd_off: u64) -> Vec<u8> {
    let mut out = Vec::new();
    for r in recs {
        out.extend_from_slice(&central_header(r));
    }
    let cd_len = out.len() as u64;
    // ZIP64 EOCD
    w32(0x06064b50, &mut out);
    w64(44, &mut out);
    w16(45, &mut out);
    w16(45, &mut out);
    w32(0, &mut out);
    w32(0, &mut out);
    w64(recs.len() as u64, &mut out);
    w64(recs.len() as u64, &mut out);
    w64(cd_len, &mut out);
    w64(cd_off, &mut out);
    // ZIP64 EOCD locator
    w32(0x07064b50, &mut out);
    w32(0, &mut out);
    w64(cd_off + cd_len, &mut out);
    w32(1, &mut out);
    // classic EOCD (truncated values; readers use the ZIP64 records)
    w32(0x06054b50, &mut out);
    w16(0, &mut out);
    w16(0, &mut out);
    w16(0xFFFF, &mut out);
    w16(0xFFFF, &mut out);
    w32(0xFFFFFFFF, &mut out);
    w32(0xFFFFFFFF, &mut out);
    w16(0, &mut out);
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn headers_and_end_have_expected_records() {
        let h = local_header("Raw/a.mp4", 123);
        assert_eq!(&h[0..4], &[0x50, 0x4b, 0x03, 0x04]);
        assert_eq!(h.len(), 30 + 9 + 20);
        let dd = data_desc(7, 123);
        assert_eq!(&dd[0..4], &[0x50, 0x4b, 0x07, 0x08]);
        assert_eq!(dd.len(), 24);
        let e = end(
            &[Rec {
                name: "Raw/a.mp4".into(),
                crc: 7,
                size: 123,
                offset: 0,
            }],
            1000,
        );
        assert_eq!(&e[0..4], &[0x50, 0x4b, 0x01, 0x02]);
        assert!(e.windows(4).any(|w| w == [0x50, 0x4b, 0x05, 0x06]));
        assert!(e.windows(4).any(|w| w == [0x50, 0x4b, 0x06, 0x06]));
    }
}
