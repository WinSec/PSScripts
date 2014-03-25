#!/usr/bin/python
import sys
import subprocess
import getpass
import os
import threading
import Queue

global v
v = -1 

# Check for the log directories, if not there create them
for logdir in ["./log","./log/new","./log/current","./log/change"]:
    if not os.path.isdir(logdir):
        os.mkdir(logdir)

def prep(host,user,pwd):
    # Upload Script, Create Service
    retcode = subprocess.call(("smbclient //" + host + "/admin$ " + pwd + " -U '" + user + """' -c "put gua.ps1" """),shell=True, stdout=v, stderr=subprocess.STDOUT), subprocess.call(('net rpc service create -I ' + host + " -U '" + user + "%" + pwd + """' USBMONsvc USBMON "cmd /c powershell.exe -executionpolicy bypass -File \\\\\\127.0.0.1\\admin$\gua.ps1 -System" """),shell=True, stdout=v, stderr=subprocess.STDOUT)
    if 1 in retcode:
        print host + ": LOGON FAILURE"
    else:
        print host + ": PREPARATION DONE"


def run(host,user,pwd):
    # Start the service
    retcode = subprocess.call(('net rpc service start -I ' + host + " -U '" + user + "%" + pwd + "' USBMONsvc"),shell=True, stdout=v, stderr=subprocess.STDOUT) 
    if retcode == 1:
        print host + ": EXECUTION FAILURE"
    else:
        print host + ": EXECUTION DONE"
 
def retrieve(host, user, pwd):
    # Retrieve results
    retcode = subprocess.call(("smbclient //" + host + "/admin$ " + pwd + " -U '" + user + """' -c "get guaresults.txt ./log/new/""" + host + '"'),shell=True, stdout=v, stderr=subprocess.STDOUT)
    if retcode == 1:
        print host + ": RESULTS FILE NOT FOUND"
    else:
        print host + ": RETRIEVAL DONE"

def clean(host,user,pwd):
    # Delete Service, Script, and output file
    subprocess.call(('net rpc service delete -I ' + host + " -U '" + user + "%" + pwd + "' USBMONsvc"),shell=True, stdout=v, stderr=subprocess.STDOUT), subprocess.call(("smbclient //" + host + "/admin$ " + pwd + " -U '" + user + """' -c "del gua.ps1" """),shell=True, stdout=v, stderr=subprocess.STDOUT), subprocess.call(("smbclient //" + host + "/admin$ " + pwd + " -U '" + user + """' -c "del guaresults.txt" """),shell=True, stdout=v, stderr=subprocess.STDOUT)
    print host + ": CLEANING DONE"

def update(host,user,pwd):
    if os.path.isfile("./log/current/" + host) and os.path.isfile("./log/new/" + host):
        if open("./log/current/" + host).read() != open("./log/new/" + host).read():
            # Write to changelog, replace current with new
            print host + ": CHANGE DETECTED"
            subprocess.call(("cat ./log/current/" + host + " ./log/new/" + host + " > ./log/change/" + host),shell=True, stdout=v, stderr=subprocess.STDOUT)
    subprocess.call(("mv ./log/new/" + host + " ./log/current/"),shell=True, stdout=v, stderr=subprocess.STDOUT)
    print host + ": UPDATE DONE"


def main():

    # Warn the user about permission issue
    if os.getuid() != 0:
        print "WARNING: YOU ARE NOT ROOT, THIS MAY CAUSE ISSUES"

    global v
    funcs = []
    hosts = {}
    pwds = {}
    threads = 3 

    if "-h" in sys.argv or "--help" in sys.argv:
        print "usage: usbget.py user@IP(s) [command] [arguments]\n\nMonitor USB usage on remote hosts.\n\noptional commands:\n  prep              push script, create service\n  run               start service\n  get               download results file\n  clean             delete all usbget files from target\n  update            update logs with new information\n\noptional arguments:\n  -t  --threads     number of threads (default: 3)\n  -v  --verbose     Be Verbose\n  -h  --help        show this help message and exit\n\nexamples:\n  usbmon.py luke@10.1.1.20-22 luke@10.1.2.1-5\n  usbmon.py luke@10.1.3.10,11 mike@10.1.1.6-9\n  usbmon.py luke@10.1.1.1,10.1.3.2 clean -v -t 1"
        exit()
    if "-v" in sys.argv or "--verbose" in sys.argv:
        v = 2
    if "-t" in sys.argv or "--threads" in sys.argv:
        try:
            threads = int(sys.argv[sys.argv.index("-t")+1])
        except:
            sys.exit("""ERROR: "threads" provided is not an int.""")
    if "prep" in sys.argv:
        funcs.append(prep)
    if "run" in sys.argv:
        funcs.append(run)
    if "get" in sys.argv:
        funcs.append(retrieve)
    if "clean" in sys.argv:
        funcs.append(clean)
    if "update" in sys.argv:
        funcs.append(update)

    # check for commands
    if len(funcs) == 0:
        funcs = [prep,run,retrieve,clean,update]

    for arg in sys.argv:
        if arg.count(".") >= 3 and "@" in arg:
            # Clear targets
            targets=[]
            # Parse user
            user = arg.split("@")[0]
            # allows support for user1@10.1.1.1 user1@10.1.1.2 
            if not user in hosts.keys():
                hosts[user]=[]
            # Parse IP of user@IP
            IP = arg.split("@")[1]
            if "-" in IP or "," in IP:
                if "-" in IP:
                    targets.append(IP.split("-")[0])
                    if (int(IP.split("-")[1]) < int(IP.split("-")[0].split(".")[3])):
                        # 10.1.1.5-1
                        for i in range(int(IP.split("-")[0].split(".")[3]) - int(IP.split("-")[1])):
                            targets.append(".".join(IP.split("-")[0].split(".")[:3]) + "." + str(int(IP.split("-")[0].split(".")[3]) - i - 1))
                    else:
                        # 10.1.1.1-5
                        for i in range(int(IP.split("-")[1]) - int(IP.split("-")[0].split(".")[3])):
                            targets.append(".".join(IP.split("-")[0].split(".")[:3]) + "." + str(int(IP.split("-")[0].split(".")[3]) + i + 1))
                    hosts[user]+=targets
                if "," in IP:
                    if len(IP.split(",")[1]) > 3:
                        # 10.1.1.1,10.1.1.2
                        hosts[user] += IP.split(",")
                    else:
                        # 10.1.1.1,2,3
                        targets.append(IP.split(",")[0])
                        for fourthquarter in IP.split(",")[1:]:
                            targets.append(".".join(IP.split(".")[:3]) + "." + fourthquarter)
                        hosts[user]+=targets
            else:
                # 10.1.1.1
                hosts[user].append(IP)
            
            # Remove Duplicates
            seen = set()
            seen_add = seen.add
            hosts[user] = [ x for x in hosts[user] if x not in seen and not seen_add(x)]

    # check for hosts
    if len(hosts.keys()) == 0:
        sys.exit("No target hosts specified.")

    # create the queue for the threads to refer to
    ToDo = Queue.Queue()

    # start all the threads
    for i in range(threads):
        thread = threading.Thread(target=worker, args=(ToDo,funcs))
        thread.daemon = True
        thread.start()
    
    for user in hosts.keys():
        ## Grab Password 
        for i in range(3):
            pwds[user] = getpass.getpass(user + "'s password: ")
            if pwds[user] != "":
                break
            if i == 2:
                sys.exit("You must enter a password.")

        # loop through hosts and add them to the queue 
        for host in hosts[user]:
                ToDo.put([host,user,pwds[user]])

    ToDo.join()

def worker(ToDo, funcs):
    while True:
        get=ToDo.get()
        for func in funcs:
            func(get[0],get[1],get[2])

        ToDo.task_done()

if __name__ == "__main__":
    main()

