# Oximeter

The CMI PC-66H Oximeter is a handheld oximeter.  It measures oxygen level and pulse rates.  Data for sessions are recorded on the device for future retrieval.  The device comes with instructions on downloading Windows software for retrieving the data via serial communications.

This repo contains software to retreive and display the data from the device using MacOSX.

### NOTE: This code and documentation should not be used for medical purposes. This software has not been tested or validated.  All data displayed by the software should be deemed unreliable and unusable for any purposes. 

## Communication Protocol

This is not complete and has been compiled from observation.

|&nbsp;| Command  | Payload | Name/Purpose  | Expected Response  | Notes |
|---|:---:|:---:|:---:|:---:|---|
|1|55 AA 01| N/A| Handshake/Wakeup  |  55 AA 01 00 |
|2|55 AA F9|  N/A |  ?? |  55 AA 01 01 | Also a handshake? |
|3|55 AA 01 55 AA F9|N/A|??| &nbsp;|combined 1 & 2 |
|4|55 AA FC| N/A|??|55 AA 01 01
|5|55 AA 02| N/A | Request # of records available | 55 AA XX YY 55 AA 01 00 | 0xXXYY is number of records available|
|6|55 AA 03|XX YY| Request record header for record 0xXXYY| 55 AA 03 YY MM DD HH MM SS RR MO 00 B4 55 AA 01 | See notes below|

### Decoding Notes

Response for a record header request:

Comes in the form:

```55 AA 03 YY MM DD HH MM SS RR MD II JJ 55 AA 01```

The first three (55 AA 03) and last 3 (55 AA 01) bytes are the message header and footer.

```YY/MM/DD HH:MM:SS``` is the start time for the record.  These byte values are in decimal format.  i.e. the value 0x20 for YY decodes to the year 2020, 0x03 for MM is March

```RR``` is the recording interval.  It should be 0x01, 0x02, 0x04 or 0x08.

```MD``` is the mode. 0x22 is Adult, 0x42 is Pediatric.

```0xIIJJ``` is the value used to determine the end time. 

```delta = (0xIIJJ/0x03 * 0xRR) - 0xRR```

delta is the number of seconds from start time to end time.

> Side Note: I'd love to know why the delta time is stored this way.  Why the divide by three, multiple and subtract? All of the other data is fairly straight forward, so I don't think this is an effort to obfuscate the data.







