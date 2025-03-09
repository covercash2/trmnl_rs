use std::time::Duration;

use esp_idf_svc::{
    eventloop::EspSystemEventLoop,
    hal::{
        modem::Modem,
        peripheral::{self, Peripheral},
        prelude::Peripherals,
    },
    http::{self, server::EspHttpServer, Method},
    io::{EspIOError, Write as _},
    wifi::{self, AuthMethod, BlockingWifi, ClientConfiguration, EspWifi},
};
use trmnl_core::{Error, Ssid, WifiPsk};

/// build time configuration for the firmware.
/// by definition, this will read a `cfg.toml` file
#[toml_cfg::toml_config]
pub struct Config {
    #[default("")]
    ssid: &'static str,
    #[default("")]
    wifi_psk: &'static str,
}

/// the verified configuration.
/// strings are not empty, paths are valid, etc.
struct VerifiedConfig {
    ssid: trmnl_core::Ssid,
    wifi_psk: trmnl_core::WifiPsk,
}

impl TryFrom<Config> for VerifiedConfig {
    type Error = trmnl_core::Error;

    fn try_from(config: Config) -> Result<Self, Self::Error> {
        let ssid = trmnl_core::Ssid::new(config.ssid)?;
        let wifi_psk = trmnl_core::WifiPsk::new(config.wifi_psk)?;

        Ok(Self { ssid, wifi_psk })
    }
}

fn main() -> anyhow::Result<()> {
    // It is necessary to call this function once. Otherwise some patches to the runtime
    // implemented by esp-idf-sys might not link properly. See https://github.com/esp-rs/esp-idf-template/issues/71
    esp_idf_svc::sys::link_patches();

    // Bind the log crate to the ESP Logging facilities
    esp_idf_svc::log::EspLogger::initialize_default();

    let peripherals = Peripherals::take()?;
    let sysloop = EspSystemEventLoop::take()?;

    log::info!("initializing firmware");

    // `CONFIG` is defined by `toml_cfg::toml_config`
    let config = CONFIG;
    let config = VerifiedConfig::try_from(config)?;

    let _wifi = wifi(config.ssid, config.wifi_psk, peripherals.modem, sysloop)?;

    log::info!("Hello, world!");

    let _http_server = Server::default();

    loop {
        std::thread::sleep(Duration::from_millis(1000));
    }
}

#[allow(unused)]
pub struct Server(Box<EspHttpServer<'static>>);

/// WARN: this will panic if the server cannot be created.
impl Default for Server {
    fn default() -> Self {
        make_server().expect("failed to create server")
    }
}

impl Server {
    pub fn new(server: EspHttpServer<'static>) -> Self {
        Self(Box::new(server))
    }
}

impl From<EspHttpServer<'static>> for Server {
    fn from(server: EspHttpServer<'static>) -> Self {
        Self::new(server)
    }
}

fn make_server() -> anyhow::Result<Server> {
    let mut server = EspHttpServer::new(&http::server::Configuration::default())?;

    server.fn_handler(
        "/",
        Method::Get,
        |request| -> core::result::Result<(), EspIOError> {
            let html = "<html><body><h1>Hello, world!</h1></body></html>";
            let mut response = request.into_ok_response()?;
            response.write_all(html.as_bytes())?;

            Ok(())
        },
    )?;

    Ok(server.into())
}

impl TryFrom<&WifiConfig> for ClientConfiguration {
    type Error = Error;

    fn try_from(config: &WifiConfig) -> Result<Self, Self::Error> {
        let ssid = (*config.ssid).try_into().map_err(|_| Error::InvalidSsid)?;
        let password = (*config.wifi_psk)
            .try_into()
            .map_err(|_| Error::InvalidWifiPsk)?;
        let channel = config.channel;

        Ok(ClientConfiguration {
            ssid,
            password,
            auth_method: AuthMethod::WPA2Personal,
            channel: Some(channel),
            ..Default::default()
        })
    }
}

struct WifiConfig {
    ssid: Ssid,
    wifi_psk: WifiPsk,
    channel: u8,
}

/// encapsulates the wifi handle.
/// when dropped, the wifi will be disabled.
#[allow(unused)]
pub struct Wifi(Box<EspWifi<'static>>);

impl Wifi {
    pub fn new(wifi: EspWifi<'static>) -> Self {
        Self(Box::new(wifi))
    }
}

fn wifi(
    ssid: Ssid,
    wifi_psk: WifiPsk,
    modem: impl Peripheral<P = Modem> + 'static,
    sysloop: EspSystemEventLoop,
) -> anyhow::Result<Wifi> {
    let mut esp_wifi = EspWifi::new(modem, sysloop.clone(), None)?;

    let mut wifi = BlockingWifi::wrap(&mut esp_wifi, sysloop)?;

    wifi.set_configuration(&wifi::Configuration::Client(ClientConfiguration::default()))?;

    log::info!("starting wifi");
    wifi.start()?;

    log::info!("scanning for wifi networks");
    let access_points = wifi.scan()?;
    let access_point = access_points.into_iter().find(|a| a.ssid == *ssid);

    let channel = if let Some(access_point) = access_point {
        log::info!("found access point: {:?}", access_point);
        access_point.channel
    } else {
        log::error!("no access points found");
        return Err(anyhow::anyhow!("no access points found with SSID {ssid}"));
    };

    let wifi_config = WifiConfig {
        ssid,
        wifi_psk,
        channel,
    };

    let client_config: ClientConfiguration = (&wifi_config).try_into()?;

    wifi.set_configuration(&wifi::Configuration::Client(client_config))?;

    log::info!("connecting to wifi");
    wifi.connect()?;

    log::info!("waiting for DHCP lease");
    wifi.wait_netif_up()?;

    let ip_info = wifi.wifi().sta_netif().get_ip_info()?;

    log::info!("connected to wifi: {:?}", ip_info);

    Ok(Wifi::new(esp_wifi))
}
