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

class Distribution:
    Ubuntu = "ubuntu"
    Debian = "debian"
    CENTOS = "centos"
    RHEL = "red"

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
        self.kongCustomPlugins = 'gluu-uma-pep,gluu-oauth-pep,gluu-metrics'

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
        self.cmd_cp = '/bin/cp'
        self.cmd_rm = '/bin/rm'
        self.cmd_node = '/usr/bin/node'
        self.cmd_update_rs_d = '/usr/sbin/update-rc.d'
        self.cmd_sh = '/bin/sh'
        self.cmd_update_alternatives = 'update-alternatives'
        self.cmd_chkconfig = 'chkconfig'
        self.cmd_alternatives = 'alternatives'
        self.cmd_echo = '/bin/echo'
        self.cmd_service = 'service'
        self.cmd_systemctl = 'systemctl'

        self.countryCode = ''
        self.state = ''
        self.city = ''
        self.orgName = ''
        self.admin_email = ''

        self.kongAdminListenSsl = '8445'
        self.distKongConfigFolder = '/etc/kong'
        self.distKongConfigFile = '%s/kong.conf' % self.distKongConfigFolder
        self.distLuaFolder = '/usr/local/share/lua/5.1'
        self.distGluuLuaFolder = '%s/gluu' % self.distLuaFolder
        self.distKongFolder = '%s/kong' % self.distLuaFolder
        self.distKongPluginsFolder = '%s/plugins' % self.distKongFolder

        self.optFolder = '/opt'
        self.distGluuGatewayFolder = '%s/gluu-gateway' % self.optFolder
        self.distKongaFolder = '%s/konga' % self.distGluuGatewayFolder
        self.distKongaAssestFolder = '%s/assets' % self.distKongaFolder
        self.distKongaConfigPath = '%s/config' % self.distKongaFolder
        self.distKongaConfigFile = '%s/config/local.js' % self.distKongaFolder
        self.distKongaDBFile = '%s/setup/templates/konga_db.sql' % self.distGluuGatewayFolder
        self.ggPluginsFolder = '%s/kong/plugins' % self.distGluuGatewayFolder
        self.gluuOAuthPEPPlugin = '%s/gluu-oauth-pep' % self.ggPluginsFolder
        self.gluuUMAPEPPlugin = '%s/gluu-uma-pep' % self.ggPluginsFolder
        self.gluuMetricsPlugin = '%s/gluu-metrics' % self.ggPluginsFolder
        self.removePluginList = ['ldap-auth', 'key-auth', 'basic-auth', 'jwt', 'oauth2', 'hmac-auth']
        self.ggCommanFolder = '%s/kong/common' % self.distGluuGatewayFolder

        self.distOxdServerFolder = '%s/oxd-server' % self.optFolder
        self.distOxdServerConfigPath = '%s/conf' % self.distOxdServerFolder
        self.distOxdServerConfigFile = '%s/oxd-server.yml' % self.distOxdServerConfigPath

        self.kongaService = 'gluu-gateway'
        self.oxdServerService = 'oxd-server' # change this when oxd-server-4.0 is released

        # oxd kong Property values
        self.kongaPort = '1338'
        self.kongaPolicyType = 'uma_rpt_policy'
        self.kongaOxdId = ''
        self.kongaOPHost = ''
        self.kongaClientId = ''
        self.kongaClientSecret = ''
        self.kongaOxdWeb = ''
        self.kongaKongAdminWebURL = 'http://localhost:8001'
        self.kongaOxdVersion = '4.0'
        self.ggVersion = '1.0-86'

        # oxd licence configuration
        self.oxdServerAuthorizationRedirectUri = ''
        self.oxdServerOPDiscoveryPath = ''
        self.oxdServerRedirectUris = ''
        self.oxdAuthorizationRedirectUri = 'localhost'

        # JRE setup properties
        self.jre_version = '162'
        self.jreDestinationPath = '/opt/jdk1.8.0_%s' % self.jre_version
        self.distFolder = '%s/dist' % self.distGluuGatewayFolder
        self.distAppFolder = '%s/app' % self.distFolder
        self.jre_home = '/opt/jre'
        self.jreSHFileName = 'jre-gluu.sh'
        self.isPrompt = True
        self.license = False
        self.initParametersFromJsonArgument()

        # OS types properties
        self.os_types = ['centos', 'red', 'fedora', 'ubuntu', 'debian']
        self.os_type = None
        self.os_version = None
        self.os_initdaemon = None

        # PostgreSQL config file path
        self.distPGhbaConfigPath = '/var/lib/pgsql/10/data'
        self.distPGhbaConfigFile = '%s/pg_hba.conf' % self.distPGhbaConfigPath

        # dependency zips
        self.ggNodeModulesDir = "%s/node_modules" % self.distKongaFolder
        self.ggBowerModulesDir = "%s/bower_components" % self.distKongaAssestFolder
        self.ggNodeModulesArchive = 'gg_node_modules.tar.gz'
        self.ggBowerModulesArchive = 'gg_bower_components.tar.gz'

        # third party lua library
        self.oxdWebFilePath = '%s/third-party/oxd-web-lua/oxdweb.lua' % self.distGluuGatewayFolder
        self.jsonLogicFilePath = '%s/third-party/json-logic-lua/logic.lua' % self.distGluuGatewayFolder
        self.lrucacheFilesPath = '%s/third-party/lua-resty-lrucache/lib/resty' % self.distGluuGatewayFolder
        self.JWTFilesPath = '%s/third-party/lua-resty-jwt/lib/resty/.' % self.distGluuGatewayFolder
        self.HMACFilesPath = '%s/third-party/lua-resty-hmac/lib/resty/.' % self.distGluuGatewayFolder
        self.prometheusFilePath = '%s/third-party/nginx-lua-prometheus/prometheus.lua' % self.distGluuGatewayFolder

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
            self.kongaOPHost = 'https://' + data['kongaOPHost']
            self.oxdServerOPDiscoveryPath = data['oxdServerOPDiscoveryPath'] + '/.well-known/openid-configuration'
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
        if self.os_type == Distribution.Ubuntu:
            self.run(['/etc/init.d/postgresql', 'start'])
            os.system('sudo -iu postgres /bin/bash -c "psql -c \\\"ALTER USER postgres WITH PASSWORD \'%s\';\\\""' % self.pgPwd)
            os.system('sudo -iu postgres /bin/bash -c "psql -U postgres -tc \\\"SELECT 1 FROM pg_database WHERE datname = \'kong\'\\\" | grep -q 1 || psql -U postgres -c \\\"CREATE DATABASE kong;\\\""')
            os.system('sudo -iu postgres /bin/bash -c "psql -U postgres -tc \\\"SELECT 1 FROM pg_database WHERE datname = \'konga\'\\\" | grep -q 1 || psql -U postgres -c \\\"CREATE DATABASE konga;\\\""')
            os.system('sudo -iu postgres /bin/bash -c "psql konga < %s"' % self.distKongaDBFile)
        if self.os_type == Distribution.Debian:
            self.run(['/etc/init.d/postgresql', 'start'])
            os.system('/bin/su -s /bin/bash -c "psql -c \\\"ALTER USER postgres WITH PASSWORD \'%s\';\\\"" postgres' % self.pgPwd)
            os.system('sudo -iu postgres /bin/bash -c "psql -U postgres -tc \\\"SELECT 1 FROM pg_database WHERE datname = \'kong\'\\\" | grep -q 1 || psql -U postgres -c \\\"CREATE DATABASE kong;\\\""')
            os.system('sudo -iu postgres /bin/bash -c "psql -U postgres -tc \\\"SELECT 1 FROM pg_database WHERE datname = \'konga\'\\\" | grep -q 1 || psql -U postgres -c \\\"CREATE DATABASE konga;\\\""')
            os.system('/bin/su -s /bin/bash -c "psql konga < %s" postgres' % self.distKongaDBFile)
        if self.os_type in [Distribution.CENTOS, Distribution.RHEL] and self.os_version == '7':
            # Initialize PostgreSQL first time
            self.run([self.cmd_ln, '/usr/lib/systemd/system/postgresql-10.service', '/usr/lib/systemd/system/postgresql.service'])
            self.run(['/usr/pgsql-10/bin/postgresql-10-setup', 'initdb'])
            self.renderTemplateInOut(self.distPGhbaConfigFile, self.template_folder, self.distPGhbaConfigPath)
            self.run([self.cmd_systemctl, 'enable', 'postgresql'])
            self.run([self.cmd_systemctl, 'start', 'postgresql'])
            os.system('sudo -iu postgres /bin/bash -c "psql -c \\\"ALTER USER postgres WITH PASSWORD \'%s\';\\\""' % self.pgPwd)
            os.system('sudo -iu postgres /bin/bash -c "psql -U postgres -tc \\\"SELECT 1 FROM pg_database WHERE datname = \'kong\'\\\" | grep -q 1 || psql -U postgres -c \\\"CREATE DATABASE kong;\\\""')
            os.system('sudo -iu postgres /bin/bash -c "psql -U postgres -tc \\\"SELECT 1 FROM pg_database WHERE datname = \'konga\'\\\" | grep -q 1 || psql -U postgres -c \\\"CREATE DATABASE konga;\\\""')
            os.system('sudo -iu postgres /bin/bash -c "psql konga < %s"' % self.distKongaDBFile)
        if self.os_type in [Distribution.CENTOS, Distribution.RHEL] and self.os_version == '6':
            # Initialize PostgreSQL first time
            self.run([self.cmd_ln, '/etc/init.d/postgresql-10', '/etc/init.d/postgresql'])
            self.run([self.cmd_service, 'postgresql-10', 'initdb'])
            self.renderTemplateInOut(self.distPGhbaConfigFile, self.template_folder, self.distPGhbaConfigPath)
            self.run([self.cmd_service, 'postgresql', 'start'])
            os.system('sudo -iu postgres /bin/bash -c "psql -c \\\"ALTER USER postgres WITH PASSWORD \'%s\';\\\""' % self.pgPwd)
            os.system('sudo -iu postgres /bin/bash -c "psql -U postgres -tc \\\"SELECT 1 FROM pg_database WHERE datname = \'kong\'\\\" | grep -q 1 || psql -U postgres -c \\\"CREATE DATABASE kong;\\\""')
            os.system('sudo -iu postgres /bin/bash -c "psql -U postgres -tc \\\"SELECT 1 FROM pg_database WHERE datname = \'konga\'\\\" | grep -q 1 || psql -U postgres -c \\\"CREATE DATABASE konga;\\\""')
            os.system('sudo -iu postgres /bin/bash -c "psql konga < %s"' % self.distKongaDBFile)

    def configureOxd(self):
        self.renderTemplateInOut(self.distOxdServerConfigFile, self.template_folder, self.distOxdServerConfigPath)
        if self.os_type == Distribution.Ubuntu and self.os_version == '16':
            self.run([self.cmd_service, self.oxdServerService, 'start'])
        if self.os_type in [Distribution.CENTOS, Distribution.RHEL] and self.os_version == '7':
            self.run([self.cmd_systemctl, 'start', self.oxdServerService])

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
            # Env variable is used
            testIP = "$IP_ADDRESS"
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

    def installPlugins(self):
        self.logIt('Installing luarocks packages...')
        # oxd-web-lua
        self.run([self.cmd_mkdir, '-p', self.distGluuLuaFolder])
        self.run([self.cmd_cp, self.oxdWebFilePath, self.distGluuLuaFolder])

        # json-logic-lua
        self.run([self.cmd_mkdir, '-p', '%s/rucciva' % self.distLuaFolder])
        self.run([self.cmd_cp, self.jsonLogicFilePath, '%s/rucciva/json_logic.lua' % self.distLuaFolder])

        # lua-resty-lrucache
        self.run([self.cmd_cp, '-R', '%s/lrucache' % self.lrucacheFilesPath, '%s/resty' % self.distLuaFolder])
        self.run([self.cmd_cp, '%s/lrucache.lua' % self.lrucacheFilesPath, '%s/resty' % self.distLuaFolder])

        # lua-resty-jwt
        self.run([self.cmd_cp, '-a', self.JWTFilesPath, '%s/resty' % self.distLuaFolder])

        # lua-resty-hmac
        self.run([self.cmd_cp, '-a', self.HMACFilesPath, '%s/resty' % self.distLuaFolder])

        # Prometheus
        self.run([self.cmd_cp, self.prometheusFilePath, self.distLuaFolder])

        # gluu plugins
        self.run([self.cmd_cp, '-R', self.gluuOAuthPEPPlugin, self.distKongPluginsFolder])
        self.run([self.cmd_cp, '-R', self.gluuUMAPEPPlugin, self.distKongPluginsFolder])
        self.run([self.cmd_cp, '-R', self.gluuMetricsPlugin, self.distKongPluginsFolder])

        # gluu plugins common file
        self.run([self.cmd_cp, '-R', '%s/kong-auth-pep-common.lua' % self.ggCommanFolder, self.distGluuLuaFolder])

        # Remove kong default plugins
        for plugin in self.removePluginList:
            self.run([self.cmd_rm, '-rf', '%s/%s' % (self.distKongPluginsFolder, plugin)])

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
        if self.os_type == [Distribution.Ubuntu, Distribution.Debian]:
            self.run([self.cmd_update_alternatives, '--install', '/usr/bin/java', 'java', '%s/bin/java' % (self.jre_home), '1'], shell=True)
        elif self.os_type in [Distribution.CENTOS, Distribution.RHEL]:
            self.run([self.cmd_alternatives, '--install', '/usr/bin/java', 'java', '%s/bin/java' % (self.jre_home), '1'])

    def configKonga(self):
        self.logIt('Installing konga node packages...')
        print 'Installing konga node packages...'

        if not os.path.exists(self.cmd_node):
            self.run([self.cmd_ln, '-s', '`which nodejs`', self.cmd_node])

        try:
            self.run([self.cmd_mkdir, '-p', self.ggNodeModulesDir])
            self.logIt("Extracting %s into %s" % (self.ggNodeModulesArchive, self.ggNodeModulesDir))
            self.run(['tar', '--strip', '1', '-xzf', '%s/%s' % (self.distFolder, self.ggNodeModulesArchive), '-C', self.ggNodeModulesDir, '--no-xattrs', '--no-same-owner', '--no-same-permissions'])
        except:
            self.logIt("Error encountered while extracting archive %s" % self.ggNodeModulesArchive)
            self.logIt(traceback.format_exc(), True)

        try:
            self.run([self.cmd_mkdir, '-p', self.ggBowerModulesDir])
            self.logIt("Extracting %s into %s" % (self.ggBowerModulesArchive, self.ggBowerModulesDir))
            self.run(['tar', '--strip', '1', '-xzf', '%s/%s' % (self.distFolder, self.ggBowerModulesArchive), '-C', self.ggBowerModulesDir, '--no-xattrs', '--no-same-owner', '--no-same-permissions'])
        except:
            self.logIt("Error encountered while extracting archive %s" % self.ggBowerModulesArchive)
            self.logIt(traceback.format_exc(), True)

        if self.generateClient:
            AuthorizationRedirectUri = 'https://' + self.oxdAuthorizationRedirectUri + ':' + self.kongaPort
            payload = {
                'op_host': self.kongaOPHost,
                'authorization_redirect_uri': AuthorizationRedirectUri,
                'post_logout_redirect_uri': AuthorizationRedirectUri,
                'scope': ['openid', 'oxd', 'permission'],
                'grant_types': ['authorization_code', 'client_credentials'],
                'client_name': 'KONGA_GG_UI_CLIENT'
            }
            self.logIt('Creating OXD OP client for Gluu Gateway GUI used to call oxd-server endpoints...')
            print 'Creating OXD OP client for Gluu Gateway GUI used to call oxd-server endpoints...'
            try:
                res = requests.post(self.kongaOxdWeb + '/register-site', data=json.dumps(payload), headers={'content-type': 'application/json'},  verify=False)
                resJson = json.loads(res.text)

                if res.ok:
                    self.kongaOxdId = resJson['oxd_id']
                    self.kongaClientSecret = resJson['client_secret']
                    self.kongaClientId = resJson['client_id']
                else:
                    msg = """Error: Unable to create the konga oxd client used to call the oxd-server endpoints
                    Please check oxd-server logs."""
                    print msg
                    self.logIt(msg, True)
                    self.logIt('OXD Error %s' % resJson, True)
                    sys.exit()
            except KeyError, e:
                self.logIt(resJson, True)
                self.logIt('Error: Failed to register client', True)
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
        # Env Variable is used
        self.hostname = "$HOSTNAME"
        print 'The next few questions are used to generate the Kong self-signed HTTPS certificate'
        # Env Variable is used
        self.countryCode = "$TWO_LETTER_COUNTRY_CODE"
        # Env Variable is used
        self.state = "$TWO_LETTER_STATE_CODE"
        # Env Variable is used
        self.city = "$CITY_OR_LOCATION"
        # Env Variable is used
        self.orgName = "$ORGANIZATION_NAME"
        # Env Variable is used
        self.admin_email = "$EMAIL_ADDRESS"

        # Postgres configuration
        msg = """If you already have a postgres user and database in the
            Postgres DB, then enter existing password, otherwise enter new password: """
        print msg
        pg = self.getPW()
        # Env Variable is used
        self.pgPwd = "$PGSQL_PASSWORD"

        # We are going to ask for 'OP hostname' regardless of whether we're installing oxd or not
        # Env Variable is used
        self.kongaOPHost = "$OP_HOST"
        self.oxdServerOPDiscoveryPath = self.kongaOPHost + '/.well-known/openid-configuration'

        # Konga Configuration
        msg = """The next few questions are used to configure Konga.
            If you are connecting to an existing oxd server on the network,
            make sure it's available from this server.
            """
        print msg

        # Env Variable is used
        self.kongaOxdWeb = "$OXD_SERVER_URL"
        # Env Variable is used  
        self.generateClient = self.makeBoolean("$GENERATE_CLIENT_CREDS_FOR_OXD")

        if not self.generateClient:
            self.kongaOxdId = "$OXD_ID"
            self.kongaClientId = "$CLIENT_ID"
            self.kongaClientSecret = "$CLIENT_SECRET"

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
        if self.os_type == Distribution.Ubuntu and self.os_version == '16':
            self.run([self.cmd_service, self.oxdServerService, 'stop'])
            self.run([self.cmd_service, self.kongaService, 'stop'])
            self.run([self.cmd_service, self.kongaService, 'start'])
            self.run([self.cmd_update_rs_d, self.kongaService, 'defaults'])
        elif self.os_type in [Distribution.CENTOS, Distribution.RHEL] and self.os_version == '7':
            self.run([self.cmd_systemctl, 'stop', self.oxdServerService])
            self.run([self.cmd_systemctl, 'stop', self.kongaService])
            self.run([self.cmd_systemctl, 'start', self.kongaService])
            self.run([self.cmd_systemctl, 'enable', self.kongaService])            

    def copyFile(self, inFile, destFolder):
        try:
            shutil.copy(inFile, destFolder)
            self.logIt("Copied %s to %s" % (inFile, destFolder))
        except:
            self.logIt("Error copying %s to %s" % (inFile, destFolder), True)
            self.logIt(traceback.format_exc(), True)

    def disableWarnings(self):
        if self.os_type in [Distribution.Ubuntu, Distribution.CENTOS, Distribution.RHEL] and self.os_version in ['16', '7', '6']:
            urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

    def chooseFromList(self, list_of_choices, choice_name="item", default_choice_index=0):
        return_value = None
        choice_map = {}
        chosen_index = 0
        print "\nSelect the number for the %s from the following list:" % choice_name
        for choice in list_of_choices:
            choice_map[chosen_index] = choice
            chosen_index += 1
            print "  [%i]   %s" % (chosen_index, choice)
        while not return_value:
            choice_number = self.getPrompt("Please select a number listed above", str(default_choice_index + 1))
            try:
                choice_number = int(choice_number) - 1
                if (choice_number >= 0) & (choice_number < len(list_of_choices)):
                    return_value = choice_map[choice_number]
                else:
                    print '"%i" is not a valid choice' % (choice_number + 1)
            except:
                print 'Cannot convert "%s" to a number' % choice_number
                self.logIt(traceback.format_exc(), True)
        return return_value

    def detectOSType(self):
        try:
            p = platform.linux_distribution()
            self.os_type = p[0].split()[0].lower()
            self.os_version = p[1].split('.')[0]
        except:
            self.os_type, self.os_version = self.chooseFromList(self.os_types, "Operating System")
        self.logIt('OS Type: %s OS Version: %s' % (self.os_type, self.os_version))

    def detectInitd(self):
        self.os_initdaemon = open(os.path.join('/proc/1/status'), 'r').read().split()[1]


if __name__ == "__main__":
    kongSetup = KongSetup()
    try:
        if kongSetup.isPrompt:
            msg = "------------------------------------------------------------------------------------- \n" \
                  + "The Gluu Support License (GLUU-SUPPORT)\n\n" \
                  + "Copyright (c) 2018 Gluu\n\n" \
                  + "Permission is hereby granted to any person obtaining a copy \n" \
                  + "of this software and associated documentation files (the \"Software\"), to deal \n" \
                  + "in the Software without restriction, including without limitation the rights \n" \
                  + "to use, copy, modify, merge, publish, distribute, sublicense, and/or sell \n" \
                  + "copies of the Software, and to permit persons to whom the Software is \n" \
                  + "furnished to do so, subject to the following conditions: \n\n" \
                  + "The above copyright notice and this permission notice shall be included in all \n" \
                  + "copies or substantial portions of the Software. \n\n" \
                  + "The end-user person or organization using this software has an active support \n" \
                  + "subscription while the software is in use in production. \n\n" \
                  + "THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND, EXPRESS OR \n" \
                  + "IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, \n" \
                  + "FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE \n" \
                  + "AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER \n" \
                  + "LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, \n" \
                  + "OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE \n" \
                  + "SOFTWARE. \n" \
                  + "------------------------------------------------------------------------------------- \n"
            print msg
            kongSetup.license = kongSetup.makeBoolean("$License")
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
                  + 'oxd server url'.ljust(30) + kongSetup.kongaOxdWeb.rjust(35) + "\n" \
                  + 'OP hostname'.ljust(30) + kongSetup.kongaOPHost.rjust(35) + "\n"

            if not kongSetup.generateClient:
                cnf += 'oxd_id'.ljust(30) + kongSetup.kongaOxdId.rjust(35) + "\n" \
                       + 'client_id'.ljust(30) + kongSetup.kongaClientId.rjust(35) + "\n" \
                       + 'client_secret'.ljust(30) + kongSetup.kongaClientSecret.rjust(35) + "\n"
            else:
                cnf += 'Generate client creds'.ljust(30) + repr(kongSetup.generateClient).rjust(35) + "\n"

            print cnf
            if kongSetup.isPrompt:
                proceed = True 
            else:
                proceed = True

            if proceed:
                kongSetup.detectOSType()
                kongSetup.detectInitd()
                kongSetup.disableWarnings()
                kongSetup.genKongSslCertificate()
                kongSetup.installJRE()
                kongSetup.configurePostgres()
                kongSetup.configureOxd()
                kongSetup.configKonga()
                kongSetup.renderKongConfigure()
                kongSetup.installPlugins()
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
