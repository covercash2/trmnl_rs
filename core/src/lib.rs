pub type Result<T> = core::result::Result<T, Error>;

#[derive(thiserror::Error, Debug, Clone)]
pub enum Error {
    #[error("could not parse SSID")]
    InvalidSsid,
    #[error("SSID was empty")]
    EmptySsid,
    #[error("could not parse wifi password")]
    InvalidWifiPsk,
    #[error("wifi password was empty")]
    EmptyWifiPsk,
}

#[derive(derive_more::Display, derive_more::Deref)]
pub struct Ssid(&'static str);

impl Ssid {
    pub fn new(ssid: &'static str) -> Result<Self> {
        if ssid.is_empty() {
            return Err(Error::EmptySsid);
        }
        Ok(Self(ssid))
    }
}

#[derive(derive_more::Display, derive_more::Deref)]
pub struct WifiPsk(&'static str);

impl WifiPsk {
    pub fn new(wifi_psk: &'static str) -> Result<Self> {
        if wifi_psk.is_empty() {
            return Err(Error::EmptyWifiPsk);
        }
        Ok(Self(wifi_psk))
    }
}

pub fn add(left: u64, right: u64) -> u64 {
    left + right
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn it_works() {
        let result = add(2, 2);
        assert_eq!(result, 4);
    }
}
