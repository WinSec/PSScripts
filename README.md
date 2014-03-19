# usbget.py

### Features:
* Logs USB information for remote hosts
* Logs changes in USB information
* Uses psexec method
* CPython threading

### USB Information Gathered:
* Serial Number
* Name
* Registry Name
* Port, Hub
* DiskID
* Vendor ID
* Vendor Name
* Product ID
* Product Name
* Revision Number
* Volume Name
* GUID
* Driver
* Original Install Date (setupapi)
* Original Install Date
* Last Arrival Date
* Last Removal Date

### Dependencies:
* python2.7
* smbclient
* net rpc

### Help Banner:
usage: usbget.py user@IP(s) [command] [arguments]

Monitor USB usage on remote hosts.

optional commands:
  prep              push script, create service
  run               start service
  get               download results file
  clean             delete all usbget files from target
  update            update logs with new information

optional arguments:
  -t  --threads     number of threads (default: 3)
  -v  --verbose     Be Verbose
  -h  --help        show this help message and exit

examples:
  usbmon.py luke@10.1.1.20-22 luke@10.1.2.1-5
  usbmon.py luke@10.1.3.10,11 mike@10.1.1.6-9
  usbmon.py luke@10.1.1.1,10.1.3.2 clean -v -t 1
