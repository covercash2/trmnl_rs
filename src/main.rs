use std::time::Duration;

use esp_idf_svc::{eventloop::EspSystemEventLoop, hal::prelude::Peripherals, log::EspLogger, sys::nvs_flash_init};

pub mod wifi;

fn main() -> anyhow::Result<()> {
    // It is necessary to call this function once. Otherwise some patches to the runtime
    // implemented by esp-idf-sys might not link properly. See https://github.com/esp-rs/esp-idf-template/issues/71
    esp_idf_svc::sys::link_patches();

    // Bind the log crate to the ESP Logging facilities
    esp_idf_svc::log::EspLogger::initialize_default();
    let logger = EspLogger::new();
    logger.set_target_level("wifi", log::LevelFilter::Debug)?;
    logger.set_target_level("trmnl_rs", log::LevelFilter::Debug)?;
    logger.initialize();

    unsafe {
        nvs_flash_init();
    }

    let peripherals = Peripherals::take()?;
    let sysloop = EspSystemEventLoop::take()?;

    let _wifi = wifi::wifi(
        "wirt 2.4"
            .try_into()
            .map_err(|()| anyhow::anyhow!("couldn't parse ssid"))?,
        "rosy&nina"
            .try_into()
            .map_err(|()| anyhow::anyhow!("couldn't parse password"))?,
        peripherals.modem,
        sysloop,
    )?;

    loop {
        std::thread::sleep(Duration::from_secs(1));
    }
}
