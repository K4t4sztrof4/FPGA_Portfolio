/*
Arduino-MAX30100 oximetry / heart rate integrated sensor library
Copyright (C) 2016  OXullo Intersecans <x@brainrapers.org>

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

// The example shows how to retrieve raw values from the sensor
// experimenting with the most relevant configuration parameters.
// Use the "Serial Plotter" app from arduino IDE 1.6.7+ to plot the output

#include <Wire.h>
#include "MAX30100.h"

// Sampling is tightly related to the dynamic range of the ADC.
// refer to the datasheet for further info
#define SAMPLING_RATE                       MAX30100_SAMPRATE_100HZ

// The LEDs currents must be set to a level that avoids clipping and maximises the
// dynamic range
#define IR_LED_CURRENT  MAX30100_LED_CURR_4_4MA
#define RED_LED_CURRENT MAX30100_LED_CURR_4_4MA
#define MAX30100_LED_CURR_0MA   0x00



// The pulse width of the LEDs driving determines the resolution of
// the ADC (which is a Sigma-Delta).
// set HIGHRES_MODE to true only when setting PULSE_WIDTH to MAX30100_SPC_PW_1600US_16BITS
// chose to set it to 13bit res, 200ns resolution so data would fit between 0-9999 for raw ir data display
#define PULSE_WIDTH MAX30100_SPC_PW_200US_13BITS
#define HIGHRES_MODE                        true


// Instantiate a MAX30100 sensor class
MAX30100 sensor;

unsigned long lastSend = 0;
const unsigned long SEND_INTERVAL = 10; // 1 second


void setup()
{
    Serial.begin(115200);     // USB serial (for debugging)
    Serial1.begin(115200);    // UART to FPGA (TX1 = Pin 18)

    Serial.print("Initializing MAX30100..");

    // Initialize the sensor
    // Failures are generally due to an improper I2C wiring, missing power supply
    // or wrong target chip
    if (!sensor.begin()) {
        Serial.println("FAILED");
        for(;;);
    } else {
        Serial.println("SUCCESS");
    }

    // Set up the wanted parameters
    sensor.setMode(MAX30100_MODE_SPO2_HR);
    //sensor.setLedsCurrent(IR_LED_CURRENT, MAX30100_LED_CURR_0MA);
    sensor.setLedsCurrent(IR_LED_CURRENT, MAX30100_LED_CURR_0MA);
    sensor.setLedsPulseWidth(PULSE_WIDTH);
    sensor.setSamplingRate(SAMPLING_RATE);
    sensor.setHighresModeEnabled(HIGHRES_MODE);
}

void loop()
{
    uint16_t ir, red;
    sensor.update();

    while (sensor.getRawValues(&ir, &red)) {


        unsigned long now = millis();
        if (now - lastSend >= SEND_INTERVAL) {
            lastSend = now;

            ir &= 0x1FFF;   // fit 13-bit range

            uint8_t ir_hi = (uint8_t)(ir >> 8);
            uint8_t ir_lo = (uint8_t)(ir & 0xFF);

            Serial.print(ir);
            Serial.println(", ");
            Serial1.write(ir_hi);
            Serial1.write(ir_lo);
        }
    }
}
