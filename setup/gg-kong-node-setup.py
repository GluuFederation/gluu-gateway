#!/usr/bin/python

import subprocess
import traceback
import time
import os
import sys
import socket
import json
import getpass
import pwd

class Distribution:
    Ubuntu = "ubuntu"
    Debian = "debian"
    CENTOS = "centos"
    RHEL = "red"

class KongSetup(object):
    def __init__(self):
        self.host_name = ''
        self.ip = ''
        self.tmp_folder = '/tmp'

        self.log_error = 'gg-kong-setup-error.log'
        self.log = 'gg-kong-setup.log'

        self.cmd_mkdir = '/bin/mkdir'
        self.cmd_chown = '/bin/chown'
        self.cmd_chmod = '/bin/chmod'
        self.cmd_ln = '/bin/ln'
        self.host_name = '/bin/hostname'
        self.cmd_touch = '/bin/touch'
        self.cmd_mv = '/bin/mv'
        self.cmd_cp = '/bin/cp'
        self.cmd_rm = '/bin/rm'
        self.cmd_node = '/usr/bin/node'
        self.cmd_sh = '/bin/sh'
        self.cmd_echo = '/bin/echo'
        self.cmd_service = 'service'
        self.cmd_rpm = '/bin/rpm'
        self.cmd_kong = '/usr/local/bin/kong'

        self.kong_custom_plugins = 'gluu-oauth-auth,gluu-uma-auth,gluu-uma-pep,gluu-oauth-pep,gluu-metrics,gluu-openid-connect,gluu-opa-pep'
        self.kong_ssl_cert = ''
        self.kong_ssl_key = ''
        self.kong_admin_listen_ssl_port = '8445'
        self.kong_admin_listen_port = '8001'
        self.kong_config_file = 'gg-kong-node.conf'
        self.dist_kong_config_folder = '/etc/kong'
        self.dist_kong_config_file = '%s/kong.conf' % self.dist_kong_config_folder
        self.dist_lua_folder = '/usr/local/share/lua/5.1'
        self.dist_gluu_lua_folder = '%s/gluu' % self.dist_lua_folder
        self.dist_kong_plugins_folder = '%s/kong/plugins' % self.dist_lua_folder
        self.disable_plugin_list = ['ldap-auth', 'key-auth', 'basic-auth', 'jwt', 'oauth2', 'hmac-auth']

        self.gg_plugins_folder = 'kong/plugins'
        self.gluu_oauth_auth_plugin = '%s/gluu-oauth-auth' % self.gg_plugins_folder
        self.gluu_oauth_pep_plugin = '%s/gluu-oauth-pep' % self.gg_plugins_folder
        self.gluu_uma_auth_plugin = '%s/gluu-uma-auth' % self.gg_plugins_folder
        self.gluu_uma_pep_plugin = '%s/gluu-uma-pep' % self.gg_plugins_folder
        self.gluu_openid_connect_plugin = '%s/gluu-openid-connect' % self.gg_plugins_folder
        self.gluu_metrics_plugin = '%s/gluu-metrics' % self.gg_plugins_folder
        self.gluu_opa_pep_plugin = '%s/gluu-opa-pep' % self.gg_plugins_folder
        self.remove_plugin_list = ['ldap-auth', 'key-auth', 'basic-auth', 'jwt', 'oauth2', 'hmac-auth']
        self.gg_comman_folder = 'kong/common'
        self.gg_disable_plugin_stub_folder = 'kong/disable_plugin_stub'

        # Prompt
        self.is_prompt = True
        self.license = False
        self.init_parameters_from_json_argument()

        # third party lua library
        self.third_party_folder = 'third-party'
        self.oxd_web_lua_file_path = '%s/oxd-web-lua/oxdweb.lua' % self.third_party_folder
        self.json_logic_file_path = '%s/json-logic-lua/logic.lua' % self.third_party_folder
        self.lrucache_files_path = '%s/lua-resty-lrucache/lib/resty' % self.third_party_folder
        self.lsession_files_path = '%s/lua-resty-session/lib/resty' % self.third_party_folder
        self.jwt_files_path = '%s/lua-resty-jwt/lib/resty/.' % self.third_party_folder
        self.hmac_files_path = '%s/lua-resty-hmac/lib/resty/.' % self.third_party_folder
        self.prometheus_file_path = '%s/nginx-lua-prometheus/prometheus.lua' % self.third_party_folder

        # postgres config
        self.pg_host = ''
        self.pg_port = ''
        self.pg_user = ''
        self.pg_password = ''
        self.pg_database = ''

    def init_parameters_from_json_argument(self):
        if len(sys.argv) > 1:
            self.is_prompt = False
            data = json.loads(sys.argv[1])
            self.license = data['license']
            self.pg_host = data['pg_host']
            self.pg_port = data['pg_port']
            self.pg_user = data['pg_user']
            self.pg_password = data['pg_password']
            self.pg_database = data['pg_database']

    def detect_host_name(self):
        detected_host_name = None
        try:
            detected_host_name = socket.gethostbyaddr(socket.gethostname())[0]
        except:
            try:
                detected_host_name = os.popen("/bin/hostname").read().strip()
            except:
                self.log_it("No detected hostname", True)
                self.log_it(traceback.format_exc(), True)
        return detected_host_name

    def get_ip(self):
        test_ip = None
        detected_ip = None
        try:
            test_socket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            detected_ip = [(test_socket.connect(('8.8.8.8', 80)),
                            test_socket.getsockname()[0],
                            test_socket.close()) for s in [socket.socket(socket.AF_INET, socket.SOCK_DGRAM)]][0][1]
        except:
            self.log_it("No detected IP address", True)
            self.log_it(traceback.format_exc(), True)
        if detected_ip:
            test_ip = self.get_prompt("Enter IP Address", detected_ip)
        else:
            test_ip = self.get_prompt("Enter IP Address")
        if not self.is_ip(test_ip):
            test_ip = None
            print 'ERROR: The IP Address is invalid. Try again\n'
        return test_ip

    def get_prompt(self, prompt, default_value=None):
        try:
            if default_value:
                user_input = raw_input("%s [%s] : " % (prompt, default_value)).strip()
                if user_input == '':
                    return default_value
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

    def install_plugins(self):
        self.log_it('Installing luarocks packages...')
        # oxd-web-lua
        self.run([self.cmd_mkdir, '-p', self.dist_gluu_lua_folder])
        self.run([self.cmd_cp, self.oxd_web_lua_file_path, self.dist_gluu_lua_folder])

        # json-logic-lua
        self.run([self.cmd_mkdir, '-p', '%s/rucciva' % self.dist_lua_folder])
        self.run([self.cmd_cp, self.json_logic_file_path, '%s/rucciva/json_logic.lua' % self.dist_lua_folder])

        # lua-resty-lrucache
        self.run([self.cmd_cp, '-R', '%s/lrucache' % self.lrucache_files_path, '%s/resty' % self.dist_lua_folder])
        self.run([self.cmd_cp, '%s/lrucache.lua' % self.lrucache_files_path, '%s/resty' % self.dist_lua_folder])

        # lua-resty-session
        self.run([self.cmd_cp, '-R', '%s/session' % self.lsession_files_path, '%s/resty' % self.dist_lua_folder])
        self.run([self.cmd_cp, '%s/session.lua' % self.lsession_files_path, '%s/resty' % self.dist_lua_folder])

        # lua-resty-jwt
        self.run([self.cmd_cp, '-a', self.jwt_files_path, '%s/resty' % self.dist_lua_folder])

        # lua-resty-hmac
        self.run([self.cmd_cp, '-a', self.hmac_files_path, '%s/resty' % self.dist_lua_folder])

        # Prometheus
        self.run([self.cmd_cp, self.prometheus_file_path, self.dist_lua_folder])

        # gluu plugins
        self.run([self.cmd_cp, '-R', self.gluu_oauth_auth_plugin, self.dist_kong_plugins_folder])
        self.run([self.cmd_cp, '-R', self.gluu_oauth_pep_plugin, self.dist_kong_plugins_folder])
        self.run([self.cmd_cp, '-R', self.gluu_uma_pep_plugin, self.dist_kong_plugins_folder])
        self.run([self.cmd_cp, '-R', self.gluu_uma_auth_plugin, self.dist_kong_plugins_folder])
        self.run([self.cmd_cp, '-R', self.gluu_openid_connect_plugin, self.dist_kong_plugins_folder])
        self.run([self.cmd_cp, '-R', self.gluu_metrics_plugin, self.dist_kong_plugins_folder])
        self.run([self.cmd_cp, '-R', self.gluu_opa_pep_plugin, self.dist_kong_plugins_folder])

        # gluu plugins common file
        self.run([self.cmd_cp, '-R', '%s/kong-common.lua' % self.gg_comman_folder, self.dist_gluu_lua_folder])
        self.run([self.cmd_cp, '-R', '%s/path-wildcard-tree.lua' % self.gg_comman_folder, self.dist_gluu_lua_folder])
        self.run([self.cmd_cp, '-R', '%s/json-cache.lua' % self.gg_comman_folder, self.dist_gluu_lua_folder])

        # Disable kong stock auth plugins
        for plugin in self.disable_plugin_list:
            self.run([self.cmd_cp, '-R', '%s/handler.lua' % self.gg_disable_plugin_stub_folder, "%s/%s" % (self.dist_kong_plugins_folder, plugin)])
            self.run([self.cmd_cp, '-R', '%s/migrations/init.lua' % self.gg_disable_plugin_stub_folder, "%s/%s/migrations" % (self.dist_kong_plugins_folder, plugin)])
            self.run([self.cmd_rm, '-R', '%s/%s/daos.lua' % (self.dist_kong_plugins_folder, plugin)])

        # Configure kong.conf
        self.render_template_in_out(self.kong_config_file, self.dist_kong_config_file)

    def is_ip(self, address):
        try:
            socket.inet_aton(address)
            return True
        except socket.error:
            return False

    def log_it(self, msg, error_log=False):
        if error_log:
            f = open(self.log_error, 'a')
            f.write('%s %s\n' % (time.strftime('%X %x'), msg))
            f.close()
        f = open(self.log, 'a')
        f.write('%s %s\n' % (time.strftime('%X %x'), msg))
        f.close()

    def make_boolean(self, c):
        if c in ['t', 'T', 'y', 'Y']:
            return True
        if c in ['f', 'F', 'n', 'N']:
            return False
        self.log_it("make_boolean: invalid value for true|false: " + c, True)

    def prompt_for_properties(self):
        # Certificate configuration
        print "Below question is about the postgres db which you are sharing between multiple kong nodes: "
        self.pg_host = self.get_prompt('Enter PG host')
        self.pg_port = self.get_prompt('Enter PG Port')
        self.pg_user = self.get_prompt('Enter PG User')
        self.pg_password = getpass.getpass(prompt='Enter PG Password : ')
        self.pg_database = self.get_prompt('Enter PG Database')

    def render_template_in_out(self, file_path, output_file):
        self.log_it("Rendering template %s" % file_path)
        f = open(file_path)
        template_text = f.read()
        f.close()
        newFn = open(output_file, 'w+')
        newFn.write(template_text % self.__dict__)
        newFn.close()

    def run(self, args, cwd=None, env=None, use_wait=False, shell=False):
        self.log_it('Running: %s' % ' '.join(args))
        try:
            p = subprocess.Popen(args, stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=cwd, env=env, shell=shell)
            if use_wait:
                code = p.wait()
                self.log_it('Run: %s with result code: %d' % (' '.join(args), code))
            else:
                output, err = p.communicate()
                if output:
                    self.log_it(output)
                if err:
                    self.log_it(err, True)
        except:
            self.log_it("Error running command : %s" % " ".join(args), True)
            self.log_it(traceback.format_exc(), True)

    def start_kong(self):
        self.run([self.cmd_kong, "stop"])
        self.run([self.cmd_kong, "start"])

    def choose_from_list(self, list_of_choices, choice_name="item", default_choice_index=0):
        return_value = None
        choice_map = {}
        chosen_index = 0
        print "\nSelect the number for the %s from the following list:" % choice_name
        for choice in list_of_choices:
            choice_map[chosen_index] = choice
            chosen_index += 1
            print "  [%i]   %s" % (chosen_index, choice)
        while not return_value:
            choice_number = self.get_prompt("Please select a number listed above", str(default_choice_index + 1))
            try:
                choice_number = int(choice_number) - 1
                if (choice_number >= 0) & (choice_number < len(list_of_choices)):
                    return_value = choice_map[choice_number]
                else:
                    print '"%i" is not a valid choice' % (choice_number + 1)
            except:
                print 'Cannot convert "%s" to a number' % choice_number
                self.log_it(traceback.format_exc(), True)
        return return_value

    def exit(self, message):
        print message
        self.log_it(message, True)
        sys.exit()

    def check_root(self):
        try:
            user = pwd.getpwuid(os.getuid()).pw_name
            print user
            if user != "root":
                msg="Your user is not root user, Run setup script in root user."
                print msg
                self.log_it(msg, True)
                sys.exit()
        except Exception as err:
            self.log_it("Failed to execute `pwd.getpwuid(os.getuid()).pw_name` %s " % err, True)

if __name__ == "__main__":
    kongSetup = KongSetup()
    kongSetup.check_root()
    try:
        if kongSetup.is_prompt:
            msg = """
-----------------------------------------------------
The Gluu Support License (GLUU-SUPPORT)

Copyright (c) 2019 Gluu

Permission is hereby granted to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

The end-user person or organization using this software has an active support 
subscription for this software with either Gluu or one of Gluu's OEM partners after using the 
software for more than 30 days.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
-----------------------------------------------------
            """
            print msg
            kongSetup.license = kongSetup.make_boolean(kongSetup.get_prompt('Do you acknowledge that use of the Gluu Gateway is under the Stepped-Up Support License? (y|N)', 'N'))
            print ""
        if kongSetup.license:
            if kongSetup.is_prompt:
                kongSetup.prompt_for_properties()
            print "\n"
            print "-----------------------".ljust(30) + "-----------------------".rjust(35) + "\n"
            cnf = 'Host'.ljust(30) + kongSetup.host_name.rjust(35) + "\n" \
                  + 'PG Host'.ljust(30) + kongSetup.pg_host.rjust(35) + "\n" \
                  + 'PG Port'.ljust(30) + kongSetup.pg_port.rjust(35) + "\n" \
                  + 'PG User'.ljust(30) + kongSetup.pg_user.rjust(35) + "\n" \
                  + 'PG Password'.ljust(30) + kongSetup.pg_password.rjust(35) + "\n" \
                  + 'PG Database'.ljust(30) + kongSetup.pg_database.rjust(35) + "\n"

            print cnf
            kongSetup.log_it(cnf)

            if kongSetup.is_prompt:
                proceed = kongSetup.make_boolean(kongSetup.get_prompt('Proceed with these values (Y|n)', 'Y'))
            else:
                proceed = True

            if proceed:
                kongSetup.install_plugins()
                kongSetup.start_kong()
                print "\n\nKong configuration successful!!! Please check /etc/kong/kong.conf for more configuration settings. \n\n"
            else:
                print "Exit"
        else:
            print "Exit"
    except:
        kongSetup.log_it("***** Error caught in main loop *****", True)
        kongSetup.log_it(traceback.format_exc(), True)
        print "Installation failed. See: \n  %s \n  %s \nfor more details." % (kongSetup.log, kongSetup.log_error)
