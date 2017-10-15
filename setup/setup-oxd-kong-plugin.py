import subprocess
import traceback
import time
import os
import sys
import socket

class KongSetup:
    def __init__(self):
        self.hostname = ''
        self.ip = ''

        self.cert_folder = './certs'
        self.template_folder = './templates'
        self.output_folder = './output'

        self.logError = 'oxd-kong-setup_error.log'
        self.log = 'oxd-kong-setup.log'

        self.kongConfigFile = '/etc/kong/kong.conf'
        self.kongCustomPlugins = 'oxd_uma,oxd_openid'

        self.oxdLicense = ''

        self.kongSslCert = ''
        self.kongSslKey = ''
        self.templates = {'/etc/kong/kong.conf': True}
        self.pgPwd = ''

        self.cmd_mkdir = '/bin/mkdir'

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

    def renderTemplateInOut(self, filePath, templateFolder, outputFolder):
        self.logIt("Rendering template %s" % filePath)
        fn = os.path.split(filePath)[-1]
        f = open(os.path.join(templateFolder, fn))
        template_text = f.read()
        f.close()
        newFn = open(os.path.join(outputFolder, fn), 'w+')
        newFn.write(template_text % self.__dict__)
        newFn.close()

    def startKong(self):
        return True

    def stopKong(self):
        return True

    def renderTemplate(self, filePath):
        self.renderTemplateInOut(filePath, self.template_folder, self.output_folder)

    def render_templates(self):
        self.logIt("Rendering templates")
        for filePath in self.templates.keys():
            try:
                self.renderTemplate(filePath)
            except:
                self.logIt("Error writing template %s" % filePath, True)
                self.logIt(traceback.format_exc(), True)

    def getPrompt(self, prompt, defaultValue=None):
        try:
            if defaultValue:
                user_input = raw_input("%s [%s] : " % (prompt, defaultValue)).strip()
                if user_input == '':
                    return defaultValue
                else:
                    return user_input
            else:
                input = False
                while not input:
                    user_input = raw_input("%s : " % prompt).strip()
                    if user_input != '':
                        input = True
                        return user_input
        except KeyboardInterrupt:
            sys.exit()
        except:
            return None

    def detect_hostname(self):
        detectedHostname = None
        try:
            detectedHostname = socket.gethostbyaddr(socket.gethostname())[0]
        except:
            try:
                detectedHostname = os.popen("/bin/hostname").read().strip()
            except:
                self.logIt("No detected hostname", True)
                self.logIt(traceback.format_exc(), True)
        return detectedHostname

    def isIP(self, address):
        try:
            socket.inet_aton(address)
            return True
        except socket.error:
            return False

    def get_ip(self):
        testIP = None
        detectedIP = None
        try:
            testSocket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            detectedIP = [(testSocket.connect(('8.8.8.8', 80)),
                           testSocket.getsockname()[0],
                           testSocket.close()) for s in [socket.socket(socket.AF_INET, socket.SOCK_DGRAM)]][0][1]
        except:
            self.logIt("No detected IP address", True)
            self.logIt(traceback.format_exc(), True)
        if detectedIP:
            testIP = self.getPrompt("Enter IP Address", detectedIP)
        else:
            testIP = self.getPrompt("Enter IP Address")
        if not self.isIP(testIP):
            testIP = None
            print 'ERROR: The IP Address is invalid. Try again\n'
        return testIP

    def makeFolders(self):
        try:
            self.run([self.cmd_mkdir, '-p', self.cert_folder])
            self.run([self.cmd_mkdir, '-p', self.output_folder])
        except:
            self.logIt("Error making folders", True)
            self.logIt(traceback.format_exc(), True)

    def promptForProperties(self):
        self.ip = self.getPrompt("Enter the ip address", self.get_ip())
        self.hostname = self.getPrompt("Enter Kong hostname", self.detect_hostname())

if __name__ == "__main__":
    kongSetup = KongSetup()
    try:
        kongSetup.makeFolders()
        kongSetup.promptForProperties()
        kongSetup.stopKong()
        kongSetup.render_templates()
        kongSetup.startKong()
        print "\n\n  oxd Kong installation successful! Point your browser to https://%s\n\n" % kongSetup.hostname
    except:
        kongSetup.logIt("***** Error caught in main loop *****", True)
        kongSetup.logIt(traceback.format_exc(), True)
        print "Installation failed. See: \n  %s \n  %s \nfor more details." % (kongSetup.log, kongSetup.logError)