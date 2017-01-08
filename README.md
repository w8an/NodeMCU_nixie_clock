# NodeMCU Nixie clock

This is a simple real time clock written in Lua that uses the NodeMCU timer object to keep time. The accuracy of such a clock would be very poor, so the clock is updated periodically from a NTP time source.

The clock uses six Nixie tubes to diplay the time. The Nixie tubes are multiplexed to keep component count small. A multiplexed display requires 3 output ports for the Nixie tube selector (6 tubes, 000-101 binary), and 4 output ports for the digit displayed on the current selected Nixie tube (0-9, 0000-1001 binary).

In this implementation, the multiplexer ports are on an MCU23017 port expander chip controlled via an I&#0178;C bus. This method was chosen as I have additional I&#0178;C devices to attach to this system.

 - Port A, bits 0-3, output binary coded decimal to an SN74141 (or K155ID1), **BCD to Nixie decoder driver**.
 - Port B, bits 0-5 each connect to a high voltage transistor switch network to provide the +170 Volt DC to each tube-- one tube at a time.

### NodeMCU Modules

NodeMCU firmware was built using the tool at https://nodemcu-build.com/ and contains the default modules plus the following additional modules:
  - i2c
  - rtctime

License
----

MIT
