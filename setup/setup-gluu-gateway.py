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


class KongSetup(object):
    def __init__(self):
        self.hostname = ''
        self.ip = ''

        self.installPostgress = True
        self.installRedis = True
        self.installOxd = True

        self.cert_folder = './certs'
        self.template_folder = './templates'
        self.output_folder = './output'
        self.system_folder = './system'
        self.osDefault = '/etc/default'

        self.logError = 'oxd-kong-setup_error.log'
        self.log = 'oxd-kong-setup.log'

        self.kongConfigFile = '/etc/kong/kong.conf'
        self.kongCustomPlugins = 'kong-uma-rs'

        self.oxdLicense = ''

        self.kongSslCert = ''
        self.kongSslKey = ''
        self.templates = {'/etc/kong/kong.conf': True}
        self.pgPwd = 'admin'

        self.cmd_mkdir = '/bin/mkdir'
        self.opensslCommand = '/usr/bin/openssl'
        self.cmd_chown = '/bin/chown'
        self.cmd_chmod = '/bin/chmod'
        self.cmd_ln = '/bin/ln'
        self.hostname = '/bin/hostname'
        self.cmd_touch = '/bin/touch'
        self.cmd_sudo = 'sudo'

        self.countryCode = ''
        self.state = ''
        self.city = ''
        self.orgName = ''
        self.admin_email = ''

        self.distFolder = '/opt'
        self.distOxdKongFolder = '%s/kong-plugins/gluu-gateway' % self.distFolder
        self.distOxdKongConfigPath = '%s/config' % self.distOxdKongFolder
        self.distOxdKongConfigFile = '%s/config/local.js' % self.distOxdKongFolder

        self.distOxdServerFolder = '%s/oxd-server' % self.distFolder
        self.distOxdServerConfigPath = '%s/conf' % self.distOxdServerFolder
        self.distOxdServerConfigFile = '%s/conf/oxd-conf.json' % self.distOxdServerConfigPath
        self.distOxdServerDefaultConfigFile = '%s/conf/oxd-default-site-config.json' % self.distOxdServerConfigPath

        self.oxdKongService = "oxd-kong"

        # oxd kong Property values
        self.oxdKongPort = '1338'
        self.oxdKongPolicyType = 'uma_rpt_policy'
        self.oxdKongOxdId = ''
        self.oxdKongOPHost = ''
        self.oxdKongClientId = ''
        self.oxdKongClientSecret = ''
        self.oxdKongOxdWeb = ''
        self.oxdKongKongAdminWebURL = ''
        self.oxdKongOxdVersion = 'Version 3.1.1'

        # oxd licence configuration
        self.oxdServerLicenseId = ''
        self.oxdServerPublicKey = ''
        self.oxdServerPublicPassword = ''
        self.oxdServerLicensePassword = ''
        self.oxdServerAuthorizationRedirectUri = ''
        self.oxdServerOPDiscoveryPath = ''
        self.oxdServerRedirectUris = ''

    def configureRedis(self):
        return True

    def configurePostgres(self):
        print '(Note: If you have already postgres user password then enter existing password otherwise enter new password)'
        self.pgPwd = self.getPrompt('Enter password')
        os.system('sudo -iu postgres /bin/bash -c "psql -c \\\"ALTER USER postgres WITH PASSWORD \'%s\';\\\""' % self.pgPwd)
        os.system('sudo -iu postgres /bin/bash -c "psql -c \\\"CREATE DATABASE kong OWNER postgres;\\\""')

    def configureOxd(self):
        self.installOxd = self.makeBoolean(self.getPrompt(
            'Would you like to configure oxd-server? (y - configure, n - skip)', 'y'))
        if self.installOxd:
            self.oxdKongOPHost = self.getPrompt('OP(OpenId provider) server')
            self.oxdServerOPDiscoveryPath = self.oxdKongOPHost + '/.well-known/openid-configuration'
            self.oxdServerLicenseId = self.getPrompt('License Id')
            self.oxdServerPublicKey = self.getPrompt('Public key')
            self.oxdServerPublicPassword = self.getPrompt('Public password')
            self.oxdServerLicensePassword = self.getPrompt('License password')
            self.oxdServerAuthorizationRedirectUri = self.getPrompt('Authorization redirect uri', 'https://' + self.hostname + ':' + self.oxdKongPort)

            self.renderTemplateInOut(self.distOxdServerConfigFile, self.template_folder, self.distOxdServerConfigPath)
            self.renderTemplateInOut(self.distOxdServerDefaultConfigFile, self.template_folder, self.distOxdServerConfigPath)

        self.run([self.cmd_sudo, '/etc/init.d/oxd-server', 'start'])
        self.run([self.cmd_sudo, '/etc/init.d/oxd-https-extension', 'start'])


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
        self.gen_cert('oxd-kong', self.getPW())
        self.kongSslCert = os.path.join(self.cert_folder, 'oxd-kong.crt')
        self.kongSslKey = os.path.join(self.cert_folder, 'oxd-kong.key')

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
        # install lua rocks
        self.run([self.cmd_sudo, 'luarocks', 'install', 'json-lua'])
        self.run([self.cmd_sudo, 'luarocks', 'install', 'lua-cjson'])
        self.run([self.cmd_sudo, 'luarocks', 'install', 'oxd-web-lua'])
        self.run([self.cmd_sudo, 'luarocks', 'install', 'kong-uma-rs'])

    def configOxdKong(self):
        print "Installing oxd-kong packages..."
        self.run([self.cmd_sudo, 'npm', 'install', '-g', 'bower', 'gulp', 'sails'])
        self.run([self.cmd_sudo, 'npm', 'install'], self.distOxdKongFolder, os.environ.copy(), True)
        self.run([self.cmd_sudo, 'bower', '--allow-root', 'install'], self.distOxdKongFolder, os.environ.copy(), True)

        print 'The next few questions are used to configure kong API Gateway'
        self.oxdKongOxdWeb = self.getPrompt('oxd web URL', 'http://%s:8080' % self.hostname)
        flag = self.makeBoolean(self.getPrompt(
            'Would you like to generate client_id/client_secret? (y - generate, n - enter client_id and client_secret manually)'))
        if flag:
            OPHost = ''
            AuthorizationRedirectUri = ''

            if self.installOxd:
                OPHost = self.getPrompt('OP(OpenId provider) server', self.oxdKongOPHost)
                AuthorizationRedirectUri = self.getPrompt('Authorization redirect uri', self.oxdServerAuthorizationRedirectUri)
            else:
                OPHost = self.getPrompt('OP(OpenId provider) server', 'https://' + self.hostname)
                AuthorizationRedirectUri = self.getPrompt('Authorization redirect uri', 'https://' + self.hostname + ':' + self.oxdKongPort)

            payload = {
                'op_host': OPHost,
                'authorization_redirect_uri': AuthorizationRedirectUri,
                'scope': ['openid', 'email', 'profile', 'uma_protection'],
                'grant_types': ['authorization_code'],
                'client_name': 'oxd_kong_client'
            }
            print 'Making client...'
            res = requests.post(self.oxdKongOxdWeb + '/setup-client', data=json.dumps(payload),
                                headers={'content-type': 'application/json'})
            resJson = json.loads(res.text)
            self.oxdKongOxdId = resJson['data']['oxd_id']
            self.oxdKongClientSecret = resJson['data']['client_secret']
            self.oxdKongClientId = resJson['data']['client_id']
        else:
            self.oxdKongOxdId = self.getPrompt('oxd_id')
            self.oxdKongClientId = self.getPrompt('client_id')
            self.oxdKongClientSecret = self.getPrompt('client_secret')

        self.oxdKongKongAdminWebURL = self.getPrompt('Kong Admin URL', 'http://' + self.hostname + ':8001')
        # Render kongAPI property
        self.run([self.cmd_sudo, self.cmd_touch, os.path.split(self.distOxdKongConfigFile)[-1]],
                 self.distOxdKongConfigPath, os.environ.copy(), True)
        self.renderTemplateInOut(self.distOxdKongConfigFile, self.template_folder, self.distOxdKongConfigPath)

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
        self.ip = self.get_ip()
        self.hostname = self.getPrompt('Enter Kong hostname', self.detectHostname())
        print 'The next few questions are used to generate the Kong self-signed certificate'
        self.countryCode = self.getPrompt('Country')
        self.state = self.getPrompt('State')
        self.city = self.getPrompt('City')
        self.orgName = self.getPrompt('Organization')
        self.admin_email = self.getPrompt('email')

    def renderTemplates(self):
        self.logIt("Rendering templates")
        # other property
        for filePath in self.templates.keys():
            try:
                self.renderTemplate(filePath)
            except:
                self.logIt("Error writing template %s" % filePath, True)
                self.logIt(traceback.format_exc(), True)

    def renderTemplate(self, filePath):
        self.renderTemplateInOut(filePath, self.template_folder, self.output_folder)

    def renderTemplateInOut(self, filePath, templateFolder, outputFolder):
        self.logIt("Rendering template %s" % filePath)
        fn = os.path.split(filePath)[-1]
        f = open(os.path.join(templateFolder, fn))
        template_text = f.read()
        f.close()
        newFn = open(os.path.join(outputFolder, fn), 'w+')
        newFn.write(template_text % self.__dict__)
        newFn.close()

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

    def startKong(self):
        self.run([self.cmd_sudo, "kong", "start", "-c", os.path.join(self.output_folder, 'kong.conf')])

    def stopKong(self):
        self.run([self.cmd_sudo, "kong", "stop"])

    def migrateKong(self):
        self.run([self.cmd_sudo, "kong", "migrations", "up", "-c", os.path.join(self.output_folder, 'kong.conf')])

    def installOxdKongService(self):
        self.logIt("Installing node service %s..." % self.oxdKongService)

        self.copyFile(os.path.join(self.template_folder, self.oxdKongService), self.osDefault)
        self.run([self.cmd_chown, 'root:root', '%s/%s' % (self.osDefault, self.oxdKongService)])

        self.run([
            self.cmd_ln,
            '-sf',
            os.path.join(self.system_folder, self.oxdKongService),
            '/etc/init.d/%s' % self.oxdKongService])

    def copyFile(self, inFile, destFolder):
        try:
            shutil.copy(inFile, destFolder)
            self.logIt("Copied %s to %s" % (inFile, destFolder))
        except:
            self.logIt("Error copying %s to %s" % (inFile, destFolder), True)
            self.logIt(traceback.format_exc(), True)

    def test(self):
        return True


if __name__ == "__main__":
    kongSetup = KongSetup()
    try:
        kongSetup.makeFolders()
        kongSetup.promptForProperties()
        kongSetup.configurePostgres()
        kongSetup.configureOxd()
        kongSetup.configOxdKong()
        kongSetup.genKongSslCertificate()
        kongSetup.renderTemplates()
        kongSetup.installSample()
        kongSetup.stopKong()
        kongSetup.migrateKong()
        kongSetup.startKong()
        # kongSetup.installOxdKongService()
        # kongSetup.configureRedis()
        # kongSetup.test()
        # print "\n\n  oxd Kong installation successful! Point your browser to https://%s\n\n" % kongSetup.hostname
    except:
        kongSetup.logIt("***** Error caught in main loop *****", True)
        kongSetup.logIt(traceback.format_exc(), True)
        print "Installation failed. See: \n  %s \n  %s \nfor more details." % (kongSetup.log, kongSetup.logError)
