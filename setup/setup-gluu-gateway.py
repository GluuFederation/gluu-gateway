#!/usr/bin/python

import subprocess
import traceback
import time
import os
import sys
import socket
import random
import string
import shutil
import requests
import json
import getpass
import urllib3
import platform

class KongSetup(object):
    def __init__(self):
        self.hostname = ''
        self.ip = ''

        self.installPostgress = True
        self.installRedis = True
        self.installOxd = True
        self.generateClient = True

        self.cert_folder = './certs'
        self.template_folder = './templates'
        self.output_folder = './output'
        self.system_folder = './system'
        self.osDefault = '/etc/default'
        self.profileFolder = '/etc/profile.d'

        self.logError = 'gluu-gateway-setup_error.log'
        self.log = 'gluu-gateway-setup.log'

        self.kongConfigFile = '/etc/kong/kong.conf'
        self.kongCustomPlugins = 'gluu-oauth2-rs,gluu-oauth2-client-auth'

        self.oxdLicense = ''

        self.kongSslCert = ''
        self.kongSslKey = ''
        self.pgPwd = 'admin'

        self.cmd_mkdir = '/bin/mkdir'
        self.opensslCommand = '/usr/bin/openssl'
        self.cmd_chown = '/bin/chown'
        self.cmd_chmod = '/bin/chmod'
        self.cmd_ln = '/bin/ln'
        self.hostname = '/bin/hostname'
        self.cmd_touch = '/bin/touch'
        self.cmd_mv = '/bin/mv'
        self.cmd_node = '/usr/bin/node'
        self.cmd_update_rs_d = '/usr/sbin/update-rc.d'
        self.cmd_sh = '/bin/sh'
        self.cmd_update_alternatives = 'update-alternatives'
        self.cmd_echo = '/bin/echo'
        self.cmd_service = '/usr/sbin/service'

        self.countryCode = ''
        self.state = ''
        self.city = ''
        self.orgName = ''
        self.admin_email = ''

        self.kongAdminListenSsl = '8445'
        self.distKongConfigFolder = '/etc/kong'
        self.distKongConfigFile = '%s/kong.conf' % self.distKongConfigFolder

        self.optFolder = '/opt'
        self.distGluuGatewayFolder = '%s/gluu-gateway' % self.optFolder
        self.distKongaFolder = '%s/konga' % self.distGluuGatewayFolder
        self.distKongaConfigPath = '%s/config' % self.distKongaFolder
        self.distKongaConfigFile = '%s/config/local.js' % self.distKongaFolder
        self.distKongaDBFile = '%s/setup/templates/konga_db.sql' % self.distGluuGatewayFolder

        self.distOxdServerFolder = '%s/oxd-server' % self.optFolder
        self.distOxdServerConfigPath = '/etc/oxd/oxd-server'
        self.distOxdServerConfigFile = '%s/oxd-conf.json' % self.distOxdServerConfigPath
        self.distOxdServerDefaultConfigFile = '%s/oxd-default-site-config.json' % self.distOxdServerConfigPath

        self.kongaService = "gluu-gateway"

        # oxd kong Property values
        self.kongaPort = '1338'
        self.kongaPolicyType = 'uma_rpt_policy'
        self.kongaOxdId = ''
        self.kongaOPHost = ''
        self.kongaClientId = ''
        self.kongaClientSecret = ''
        self.kongaOxdWeb = ''
        self.kongaKongAdminWebURL = 'http://localhost:8001'
        self.kongaOxdVersion = '3.1.3'
        self.ggVersion = '3.1.3'

        # oxd licence configuration
        self.oxdServerLicenseId = ''
        self.oxdServerPublicKey = ''
        self.oxdServerPublicPassword = ''
        self.oxdServerLicensePassword = ''
        self.oxdServerAuthorizationRedirectUri = ''
        self.oxdServerOPDiscoveryPath = ''
        self.oxdServerRedirectUris = ''
        self.oxdAuthorizationRedirectUri = 'localhost'

        # JRE setup properties
        self.jre_version = '162'
        self.jreDestinationPath = '/opt/jdk1.8.0_%s' % self.jre_version
        self.distAppFolder = '%s/dist/app' % self.distGluuGatewayFolder
        self.jre_home = '/opt/jre'
        self.jreSHFileName = 'jre-gluu.sh'
        self.isPrompt = True
        self.license = False
        self.initParametersFromJsonArgument()
        self.platform = platform.linux_distribution()

    def initParametersFromJsonArgument(self):
        if len(sys.argv) > 1:
            self.isPrompt = False
            data = json.loads(sys.argv[1])
            self.license = data['license']
            self.ip = data['ip']
            self.hostname = data['hostname']
            self.countryCode = data['countryCode']
            self.state = data['state']
            self.city = data['city']
            self.orgName = data['orgName']
            self.admin_email = data['admin_email']
            self.pgPwd = data['pgPwd']
            self.oxdAuthorizationRedirectUri = data['oxdAuthorizationRedirectUri']
            self.installOxd = data['installOxd']
            if self.installOxd:
                self.kongaOPHost = 'https://' + data['kongaOPHost']
                self.oxdServerOPDiscoveryPath = data['oxdServerOPDiscoveryPath'] + '/.well-known/openid-configuration'
                self.oxdServerLicenseId = data['oxdServerLicenseId']
                self.oxdServerPublicKey = data['oxdServerPublicKey']
                self.oxdServerPublicPassword = data['oxdServerPublicPassword']
                self.oxdServerLicensePassword = data['oxdServerLicensePassword']
            if not self.installOxd:
                self.kongaOPHost = 'https://' + data['kongaOPHost']
            self.kongaOxdWeb = data['kongaOxdWeb']
            self.generateClient = data['generateClient']
            if not self.generateClient:
                self.kongaOxdId = data['kongaOxdId']
                self.kongaClientId = data['kongaClientId']
                self.kongaClientSecret = data['kongaClientSecret']

    def configureRedis(self):
        return True

    def configurePostgres(self):
        self.logIt('Configuring postgres...')
        print 'Configuring postgres...'
        self.run(['/etc/init.d/postgresql', 'start'])
        os.system('sudo -iu postgres /bin/bash -c "psql -c \\\"ALTER USER postgres WITH PASSWORD \'%s\';\\\""' % self.pgPwd)
        os.system('sudo -iu postgres /bin/bash -c "psql -c \\\"CREATE DATABASE kong OWNER postgres;\\\""')
        os.system('sudo -iu postgres /bin/bash -c "psql -c \\\"CREATE DATABASE konga OWNER postgres;\\\""')
        os.system('sudo -iu postgres /bin/bash -c "psql konga < %s"' % self.distKongaDBFile)

    def configureOxd(self):
        if self.installOxd:
            self.renderTemplateInOut(self.distOxdServerConfigFile, self.template_folder, self.distOxdServerConfigPath)
            self.renderTemplateInOut(self.distOxdServerDefaultConfigFile, self.template_folder,
                                     self.distOxdServerConfigPath)

        self.run(['/etc/init.d/oxd-server', 'start'])
        self.run(['/etc/init.d/oxd-https-extension', 'start'])

    def detectHostname(self):
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

    def getExternalCassandraInfo(self):
        return True

    def getExternalOxdInfo(self):
        return True

    def getExternalPostgressInfo(self):
        return True

    def getExternalRedisInfo(self):
        return True

    def gen_cert(self, serviceName, password, user='root', cn=None):
        self.logIt('Generating Certificate for %s' % serviceName)
        key_with_password = '%s/%s.key.orig' % (self.cert_folder, serviceName)
        key = '%s/%s.key' % (self.cert_folder, serviceName)
        csr = '%s/%s.csr' % (self.cert_folder, serviceName)
        public_certificate = '%s/%s.crt' % (self.cert_folder, serviceName)
        self.run([self.opensslCommand,
                  'genrsa',
                  '-des3',
                  '-out',
                  key_with_password,
                  '-passout',
                  'pass:%s' % password,
                  '2048'
                  ])
        self.run([self.opensslCommand,
                  'rsa',
                  '-in',
                  key_with_password,
                  '-passin',
                  'pass:%s' % password,
                  '-out',
                  key
                  ])

        certCn = cn
        if certCn == None:
            certCn = self.hostname

        self.run([self.opensslCommand,
                  'req',
                  '-new',
                  '-key',
                  key,
                  '-out',
                  csr,
                  '-subj',
                  '/C=%s/ST=%s/L=%s/O=%s/CN=%s/emailAddress=%s' % (
                      self.countryCode, self.state, self.city, self.orgName, certCn, self.admin_email)
                  ])
        self.run([self.opensslCommand,
                  'x509',
                  '-req',
                  '-days',
                  '365',
                  '-in',
                  csr,
                  '-signkey',
                  key,
                  '-out',
                  public_certificate
                  ])
        self.run([self.cmd_chown, '%s:%s' % (user, user), key_with_password])
        self.run([self.cmd_chmod, '700', key_with_password])
        self.run([self.cmd_chown, '%s:%s' % (user, user), key])
        self.run([self.cmd_chmod, '700', key])

    def getPW(self, size=12, chars=string.ascii_uppercase + string.digits + string.lowercase):
        return ''.join(random.choice(chars) for _ in range(size))

    def genKongSslCertificate(self):
        self.gen_cert('gluu-gateway', self.getPW())
        self.kongSslCert = self.distGluuGatewayFolder + '/setup/certs/gluu-gateway.crt'
        self.kongSslKey = self.distGluuGatewayFolder + '/setup/certs/gluu-gateway.key'

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

    def installSample(self):
        self.logIt('Installing luarocks packages...')
        self.run(['luarocks', 'install', 'json-lua'])
        self.run(['luarocks', 'install', 'oxd-web-lua'])
        self.run(['luarocks', 'install', 'json-logic-lua'])
        self.run(['luarocks', 'install', 'gluu-oauth2-rs'])
        self.run(['luarocks', 'install', 'gluu-oauth2-client-auth'])

    def installJRE(self):
        self.logIt("Installing server JRE 1.8 %s..." % self.jre_version)
        jreArchive = 'server-jre-8u%s-linux-x64.tar.gz' % self.jre_version

        try:
            self.logIt("Extracting %s into /opt/" % jreArchive)
            self.run(['tar', '-xzf', '%s/%s' % (self.distAppFolder, jreArchive), '-C', '/opt/', '--no-xattrs', '--no-same-owner', '--no-same-permissions'])
        except:
            self.logIt("Error encountered while extracting archive %s" % jreArchive)
            self.logIt(traceback.format_exc(), True)

        self.run([self.cmd_ln, '-sf', self.jreDestinationPath, self.jre_home])
        self.run([self.cmd_chmod, '-R', '755', '%s/bin/' % self.jreDestinationPath])
        with open('/etc/environment', 'a') as f:
            f.write('JAVA_HOME=/opt/jre')
        self.run([self.cmd_update_alternatives, '--install', '/usr/bin/java', 'java', '%s/bin/java' % (self.jre_home), '1'], shell=True)


    def configKonga(self):
        self.logIt('Installing konga node packages...')
        print 'Installing konga node packages...'

        if not os.path.exists(self.cmd_node):
            self.run([self.cmd_ln, '-s', '`which nodejs`', self.cmd_node])

        self.run(['npm', 'install', '-g', 'bower', 'gulp', 'sails'])
        self.run(['npm', 'install', '--unsafe-perm'], self.distKongaFolder, os.environ.copy(), True)
        self.run(['bower', '--allow-root', 'install'], self.distKongaFolder, os.environ.copy(), True)

        if self.generateClient:
            AuthorizationRedirectUri = 'https://'+self.oxdAuthorizationRedirectUri+':' + self.kongaPort
            payload = {
                'op_host': self.kongaOPHost,
                'authorization_redirect_uri': AuthorizationRedirectUri,
                'post_logout_redirect_uri': AuthorizationRedirectUri,
                'scope': ['openid', 'uma_protection'],
                'grant_types': ['authorization_code'],
                'client_name': 'konga_client'
            }
            self.logIt('Creating konga oxd client used to call oxd-https endpoints...')
            print 'Creating konga oxd client used to call oxd-https endpoints...'
            try:
                res = requests.post(self.kongaOxdWeb + '/setup-client', data=json.dumps(payload), headers={'content-type': 'application/json'},  verify=False)
                resJson = json.loads(res.text)

                if resJson['status'] == 'ok':
                    self.kongaOxdId = resJson['data']['oxd_id']
                    self.kongaClientSecret = resJson['data']['client_secret']
                    self.kongaClientId = resJson['data']['client_id']
                else:
                    msg = """Error: Unable to create the konga oxd client used to call the oxd-https endpoints
                    Please check oxd-server and oxd-https logs."""
                    print msg
                    self.logIt(msg, True)
                    self.logIt('OXD Error %s' % resJson, True)
                    sys.exit()
            except requests.exceptions.HTTPError as e:
                self.logIt('Error: Failed to connect %s' % self.kongaOxdWeb, True)
                self.logIt('%s' % e, True)
                sys.exit()

        # Render konga property
        self.run([self.cmd_touch, os.path.split(self.distKongaConfigFile)[-1]],
                 self.distKongaConfigPath, os.environ.copy(), True)
        self.renderTemplateInOut(self.distKongaConfigFile, self.template_folder, self.distKongaConfigPath)

    def isIP(self, address):
        try:
            socket.inet_aton(address)
            return True
        except socket.error:
            return False

    def logIt(self, msg, errorLog=False):
        if errorLog:
            f = open(self.logError, 'a')
            f.write('%s %s\n' % (time.strftime('%X %x'), msg))
            f.close()
        f = open(self.log, 'a')
        f.write('%s %s\n' % (time.strftime('%X %x'), msg))
        f.close()

    def makeBoolean(self, c):
        if c in ['t', 'T', 'y', 'Y']:
            return True
        if c in ['f', 'F', 'n', 'N']:
            return False
        self.logIt("makeBoolean: invalid value for true|false: " + c, True)

    def makeFolders(self):
        try:
            self.run([self.cmd_mkdir, '-p', self.cert_folder])
            self.run([self.cmd_mkdir, '-p', self.output_folder])
        except:
            self.logIt("Error making folders", True)
            self.logIt(traceback.format_exc(), True)

    def promptForProperties(self):
        # Certificate configuration
        self.ip = self.get_ip()
        self.hostname = self.getPrompt('Enter kong hostname', self.detectHostname())
        print 'The next few questions are used to generate the Kong self-signed HTTPS certificate'
        self.countryCode = self.getPrompt('Enter two letter Country Code')
        self.state = self.getPrompt('Enter two letter State Code')
        self.city = self.getPrompt('Enter your city or locality')
        self.orgName = self.getPrompt('Enter Organization name')
        self.admin_email = self.getPrompt('Enter email address')

        # Postgres configuration
        msg = """If you already have a postgres user and database in the
            Postgres DB, then enter existing password, otherwise enter new password: """
        print msg
        pg = self.getPW()
        self.pgPwd = getpass.getpass(prompt='Password [%s] : ' % pg) or pg

        # OXD Configuration
        self.installOxd = self.makeBoolean(self.getPrompt(
            'Would you like to configure oxd-server? (y - configure, n - skip)', 'y'))
        if self.installOxd:
            self.kongaOPHost = 'https://' + self.getPrompt('OP hostname')
            self.oxdServerOPDiscoveryPath = self.kongaOPHost + '/.well-known/openid-configuration'
            self.oxdServerLicenseId = self.getPrompt('License Id')
            self.oxdServerPublicKey = self.getPrompt('Public key')
            self.oxdServerPublicPassword = self.getPrompt('Public password')
            self.oxdServerLicensePassword = self.getPrompt('License password')

        # Konga Configuration
        msg = """The next few questions are used to configure Konga.
            If you are connecting to an existing oxd-https server on the network,
            make sure it's available from this server.
            """
        print msg

        if not self.installOxd:
            self.kongaOPHost = 'https://' + self.getPrompt('OP hostname')

        self.kongaOxdWeb = self.getPrompt('oxd https url', 'https://%s:8443' % self.hostname)
        self.generateClient = self.makeBoolean(self.getPrompt("Generate client creds to call oxd-https API's? (y - generate, n - enter client_id and client_secret manually)", 'y'))

        if not self.generateClient:
            self.kongaOxdId = self.getPrompt('oxd_id')
            self.kongaClientId = self.getPrompt('client_id')
            self.kongaClientSecret = self.getPrompt('client_secret')

    def renderKongConfigure(self):
        self.renderTemplateInOut(self.distKongConfigFile, self.template_folder, self.distKongConfigFolder)

    def renderTemplateInOut(self, filePath, templateFolder, outputFolder):
        self.logIt("Rendering template %s" % filePath)
        fn = os.path.split(filePath)[-1]
        f = open(os.path.join(templateFolder, fn))
        template_text = f.read()
        f.close()
        newFn = open(os.path.join(outputFolder, fn), 'w+')
        newFn.write(template_text % self.__dict__)
        newFn.close()

    def run(self, args, cwd=None, env=None, useWait=False, shell=False):
        self.logIt('Running: %s' % ' '.join(args))
        try:
            p = subprocess.Popen(args, stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=cwd, env=env, shell=shell)
            if useWait:
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

    def startKong(self):
        self.run(["kong", "stop"])
        self.run(["kong", "start"])

    def migrateKong(self):
        self.run(["kong", "migrations", "up"])

    def startKongaService(self):
        self.logIt("Starting %s..." % self.kongaService)
        self.run(['/etc/init.d/oxd-server', 'stop'])
        self.run(['/etc/init.d/oxd-https-extension', 'stop'])
        self.run(["/etc/init.d/%s" % self.kongaService, "stop"])
        self.run(["/etc/init.d/%s" % self.kongaService, "start"])
        self.run([self.cmd_update_rs_d, self.kongaService, "defaults"])

    def copyFile(self, inFile, destFolder):
        try:
            shutil.copy(inFile, destFolder)
            self.logIt("Copied %s to %s" % (inFile, destFolder))
        except:
            self.logIt("Error copying %s to %s" % (inFile, destFolder), True)
            self.logIt(traceback.format_exc(), True)
    def disableWarnings(self):
        if self.platform[1].split(".")[0] == '16':
            urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)


if __name__ == "__main__":
    kongSetup = KongSetup()
    try:
        if kongSetup.isPrompt:
            msg = "------------------------------------------------------------------------------------- \n" \
              + "The MIT License (MIT) \n\n" \
              + "Copyright (c) 2017 Gluu \n\n" \
              + "Permission is hereby granted, free of charge, to any person obtaining a copy \n" \
              + "of this software and associated documentation files (the 'Software'), to deal \n" \
              + "in the Software without restriction, including without limitation the rights \n" \
              + "to use, copy, modify, merge, publish, distribute, sublicense, and/or sell \n" \
              + "copies of the Software, and to permit persons to whom the Software is \n" \
              + "furnished to do so, subject to the following conditions: \n\n" \
              + "The above copyright notice and this permission notice shall be included in all \n" \
              + "copies or substantial portions of the Software. \n\n" \
              + "THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND, EXPRESS OR \n" \
              + "IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, \n" \
              + "FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE \n" \
              + "AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER \n" \
              + "LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, \n" \
              + "OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE \n" \
              + "SOFTWARE. \n" \
              + "------------------------------------------------------------------------------------- \n"
            print msg
            kongSetup.license = kongSetup.makeBoolean(kongSetup.getPrompt('Do you acknowledge that use of the Gluu Gateway is under the MIT license? (y|N)', 'N'))
            print ""
        if kongSetup.license:
            kongSetup.makeFolders()
            if kongSetup.isPrompt:
                kongSetup.promptForProperties()
            print "\n"
            print "-----------------------".ljust(30) + "-----------------------".rjust(35) + "\n"
            cnf = 'hostname'.ljust(30) + kongSetup.hostname.rjust(35) + "\n" \
                  + 'orgName'.ljust(30) + kongSetup.orgName.rjust(35) + "\n" \
                  + 'city'.ljust(30) + kongSetup.city.rjust(35) + "\n" \
                  + 'state'.ljust(30) + kongSetup.state.rjust(35) + "\n" \
                  + 'country'.ljust(30) + kongSetup.countryCode.rjust(35) + "\n" \
                  + 'Configure oxd-server'.ljust(30) + repr(kongSetup.installOxd).rjust(35) + "\n" \
                  + 'oxd https url'.ljust(30) + kongSetup.kongaOxdWeb.rjust(35) + "\n"

            if kongSetup.installOxd:
                cnf += 'OP hostname'.ljust(30) + kongSetup.kongaOPHost.rjust(35) + "\n" \
                      + 'License Id'.ljust(30) + kongSetup.oxdServerLicenseId.rjust(35) + "\n" \
                      + 'Public key'.ljust(30) + kongSetup.oxdServerPublicKey.rjust(35) + "\n" \
                      + '\nPublic password'.ljust(30) + kongSetup.oxdServerPublicPassword.rjust(35) + "\n" \
                      + 'License password'.ljust(30) + kongSetup.oxdServerLicensePassword.rjust(35) + "\n"
            else:
                cnf += 'OP hostname'.ljust(30) + kongSetup.kongaOPHost.rjust(35) + "\n"

            if not kongSetup.generateClient:
                cnf += 'oxd_id'.ljust(30) + kongSetup.kongaOxdId.rjust(35) + "\n" \
                      + 'client_id'.ljust(30) + kongSetup.kongaClientId.rjust(35) + "\n" \
                      + 'client_secret'.ljust(30) + kongSetup.kongaClientSecret.rjust(35) + "\n"
            else:
                cnf += 'Generate client creds'.ljust(30) + repr(kongSetup.generateClient).rjust(35) + "\n"

            print cnf
            if kongSetup.isPrompt:
                proceed = kongSetup.makeBoolean(kongSetup.getPrompt('Proceed with these values (Y|n)', 'Y'))
            else:
                proceed = True

            if proceed:
                kongSetup.disableWarnings()
                kongSetup.genKongSslCertificate()
                kongSetup.installJRE()
                kongSetup.configurePostgres()
                kongSetup.configureOxd()
                kongSetup.configKonga()
                kongSetup.renderKongConfigure()
                kongSetup.installSample()
                kongSetup.migrateKong()
                kongSetup.startKong()
                kongSetup.startKongaService()
                print "\n\nGluu Gateway configuration successful!!! https://localhost:%s\n\n" % kongSetup.kongaPort
            else:
                print "Exit"
        else:
            print "Exit"
    except:
        kongSetup.logIt("***** Error caught in main loop *****", True)
        kongSetup.logIt(traceback.format_exc(), True)
        print "Installation failed. See: \n  %s \n  %s \nfor more details." % (kongSetup.log, kongSetup.logError)
