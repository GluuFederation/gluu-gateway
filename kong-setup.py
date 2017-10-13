import subprocess
import traceback
import time
import sys
import os

class KongSetup:

    def __init__(self):
        self.logError = 'setup_error.log'
        self.log = 'setup.log'

    def logIt(self, msg, errorLog=False):
        if errorLog:
            f = open(self.logError, 'a')
            f.write('%s %s\n' % (time.strftime('%X %x'), msg))
            f.close()
        f = open(self.log, 'a')
        f.write('%s %s\n' % (time.strftime('%X %x'), msg))
        f.close()

    def run(self, args, cwd=None, env=None, usewait=False):
        self.logIt('Running: %s' % ' '.join(args))
        try:
            p = subprocess.Popen(args, stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=cwd, env=env)
            if usewait:
                code = p.wait()
                self.logIt('Run: %s with result code: %d' % (' '.join(args), code))
            else:
                output, err = p.communicate()
                if output:
                    self.logIt(output)
                if err:
                    self.logIt(err, True)
        except:
            self.logIt("Error running command : %s" % " ".join(args), True)
            self.logIt(traceback.format_exc(), True)

    def dbSetup(self):
        originalDBConfigFile = os.path.join("/etc", "kong", "kong.conf")
        newDBConfigFile = ""
        input_file = open(originalDBConfigFile)
        try:
            for i, line in enumerate(input_file):
                if line[0:21] == "#database = cassandra":
                    line = line[1:]

                newDBConfigFile += line

        except Exception, e:
            self.logIt("Error in writing kong.config file", True)
            self.logIt(traceback.format_exc(), True)

        finally:
            input_file.close()
            f = open(originalDBConfigFile, "w")
            f.write(newDBConfigFile)

if __name__ == "__main__":
    print sys.argv
    obj = KongSetup()

    print "\nInstalling..."
    obj.run(["sudo", "apt-get", "update"])

    print "\nInstalling kong..."
    # kong-0.10.3.trusty_all.deb
    obj.run(["sudo", "chmod", "777", "kong-community-edition-0.11.0.trusty.all.deb"])
    obj.run(["sudo", "dpkg", "-i", "kong-community-edition-0.11.0.trusty.all.deb"])

    # cassandra db configuration
    obj.dbSetup()

    obj.run(["sudo", "kong", "migrations", "up"])
    obj.run(["sudo", "kong", "start"])
