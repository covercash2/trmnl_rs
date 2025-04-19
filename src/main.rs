use esp_idf_sys as _; // If using the `binstart` feature of `esp-idf-sys`, always keep this module imported
use esp_idf_hal::prelude::*;
use esp_idf_hal::gpio::*;
use esp_idf_hal::delay::FreeRtos;
use log::*;

fn main() {
    // It is necessary to call this function once. Otherwise some patches to the runtime
    // implemented by esp-idf-sys might not link properly. See https://github.com/esp-rs/esp-idf-template/issues/71
    esp_idf_sys::link_patches();

    // Initialize logger
    esp_idf_svc::log::EspLogger::initialize_default();

    info!("Hello, ESP32-C3!");

    let peripherals = Peripherals::take().unwrap();
    let mut led = PinDriver::output(peripherals.pins.gpio2).unwrap();

    info!("Starting blink loop");

    loop {
        led.set_high().unwrap();
        info!("LED ON");
        FreeRtos::delay_ms(1000);

        led.set_low().unwrap();
        info!("LED OFF");
        FreeRtos::delay_ms(1000);
    }
}
