use esp_idf_svc::{
    eventloop::EspSystemEventLoop,
    hal::{modem::Modem, peripheral::Peripheral},
    wifi::{AuthMethod, BlockingWifi, ClientConfiguration, Configuration, EspWifi},
};
use heapless::String;

pub fn wifi(
    ssid: String<32>,
    password: String<64>,
    modem: impl Peripheral<P = Modem> + 'static,
    sysloop: EspSystemEventLoop,
) -> anyhow::Result<Box<EspWifi<'static>>> {
    log::info!("starting wifi {ssid} {password} ...");

    let mut esp_wifi = EspWifi::new(modem, sysloop.clone(), None)?;
    let mut wifi = BlockingWifi::wrap(&mut esp_wifi, sysloop)?;

    wifi.set_configuration(&Configuration::default())?;

    wifi.start()?;

    log::info!("scanning...");

    let ap_infos = wifi.scan()?;

    let channel = ap_infos
        .into_iter()
        .find(|a| a.ssid == ssid)
        .map(|ap| ap.channel)
        .ok_or(anyhow::anyhow!("could not find configured SSID"))?;

    wifi.set_configuration(&Configuration::Client(ClientConfiguration {
        ssid,
        password,
        auth_method: AuthMethod::WPA2Personal,
        channel: Some(channel),
        ..Default::default()
    }))?;

    log::info!("connecting wifi...");

    wifi.connect()?;

    log::info!("waiting for DHCP lease...");

    wifi.wait_netif_up()?;

    let ip_info = wifi.wifi().sta_netif().get_ip_info()?;

    log::info!("wifi DHCP info: {ip_info:?}");

    Ok(Box::new(esp_wifi))
}
