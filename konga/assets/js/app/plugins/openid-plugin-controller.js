(function () {
  'use strict';

  angular.module('frontend.plugins')
    .controller('OpenIDPluginController', [
      '_', '$scope', '$log', '$state', 'PluginsService', 'MessageService',
      '$uibModal', 'DialogService', 'PluginModel', 'PluginHelperService', '_route', '_info', '_plugins', '$compile', 'InfoService', '$localStorage',
      function controller(_, $scope, $log, $state, PluginsService, MessageService,
                          $uibModal, DialogService, PluginModel, PluginHelperService, _route, _info, _plugins, $compile, InfoService, $localStorage) {
        $scope.globalInfo = $localStorage.credentials.user;
        $scope.route = (_route && _route.data) || null;
        $scope.info = (_info && _info.data) || null;
        $scope.upstream_url = '';
        $scope.plugins = _plugins.data.data;
        $scope.oauthPlugin = null;
        $scope.addNewScope = addNewScope;
        $scope.managePlugin = managePlugin;
        $scope.getDiscoveryResponse = getDiscoveryResponse;
        $scope.customHeaders = [['CUSTOM_NUMBER', '123321123']];
        $scope.claimSupported = [['role', '==', '[Mm][Aa]']];
        $scope.timeType = ['seconds', 'minutes', 'hours', 'days'];
        $scope.headerFormats = ["string", "jwt", "base64", "urlencoded", "list"];
        $scope.op_acr_values_supported = ['auth_ldap_server'];
        $scope.getKongProxyURL = getKongProxyURL;

        $scope.addNewCondition = addNewCondition;
        $scope.addNewPath = addNewPath;
        $scope.addACRNewCondition = addACRNewCondition;
        $scope.addACRNewPath = addACRNewPath;
        $scope.showResourceJSON = showResourceJSON;
        $scope.showACRExpressionJSON = showACRExpressionJSON;
        $scope.managePlugin = managePlugin;
        $scope.loadACRMethods = loadACRMethods;
        $scope.loadMethods = loadMethods;
        $scope.loadScopes = loadScopes;
        $scope.addGroup = addGroup;
        $scope.removeGroup = removeGroup;
        $scope.openCreateConsumerModal = openCreateConsumerModal;
        $scope.openConsumerListModal = openConsumerListModal;
        $scope.showPathPossibilities = showPathPossibilities;
        $scope.showCustomHeadersGuide = showCustomHeadersGuide;
        $scope.isAllowPEP = true;
        $scope.authSwitchClicked = authSwitchClicked;
        $scope.addCustomHeader = addCustomHeader;

        $scope.pluginConfig = {
          isPEPEnabled: true
        };
        $scope.isPluginAdded = false;
        $scope.alreadyAddedUMAExpression = false;
        var pepPlugin, oidcPlugin;
        $scope.plugins.forEach(function (o) {
          if (o.name === "gluu-openid-connect") {
            oidcPlugin = o;
            $scope.isPluginAdded = true;
          }

          if (o.name == "gluu-uma-pep") {
            pepPlugin = o;
          }

          if (o.name === "gluu-opa-pep") {
            $scope.isAllowPEP = false;
            $scope.pluginConfig.isPEPEnabled = false;
          }
        });

        if ($scope.isPluginAdded && oidcPlugin) {
          $scope.isPluginAdded = true;
          $scope.pluginConfig = oidcPlugin.config;
          $scope.pluginConfig.tags = oidcPlugin.tags;
          $scope.pluginConfig.openid_connect_id = oidcPlugin.id;
          $scope.pluginConfig.isPEPEnabled = false;
          if ($scope.pluginConfig.required_acrs_expression) {
            $scope.pluginConfig.required_acrs_expression = JSON.parse($scope.pluginConfig.required_acrs_expression);
            $scope.pluginConfig.isACRExpEnabled = true;
            $scope.pluginConfig.required_acrs_expression.forEach(function (path, pIndex) {
              path.conditions.forEach(function (cond, cIndex) {
                if (cond.required_acrs) {
                  cond.apply_auth = true
                } else {
                  cond.apply_auth = false
                }
              });
            });
          } else {
            $scope.pluginConfig.required_acrs_expression = [];
            $scope.pluginConfig.isACRExpEnabled = false;
          }

          var maxAge = convertSeconds($scope.pluginConfig.max_id_token_age);
          var maxAuthAge = convertSeconds($scope.pluginConfig.max_id_token_auth_age);
          $scope.pluginConfig.max_id_token_age_value = maxAge.value;
          $scope.pluginConfig.max_id_token_age_type = maxAge.type;
          $scope.pluginConfig.max_id_token_auth_age_value = maxAuthAge.value;
          $scope.pluginConfig.max_id_token_auth_age_type = maxAuthAge.type;
          if (pepPlugin) {
            $scope.pluginConfig.pepId = pepPlugin.id;
            $scope.pluginConfig.isPEPEnabled = true;
            $scope.alreadyAddedUMAExpression = true;
            $scope.pluginConfig.deny_by_default = pepPlugin.config.deny_by_default;
            $scope.pluginConfig.redirect_claim_gathering_url = pepPlugin.config.redirect_claim_gathering_url || false;
            $scope.pluginConfig.claims_redirect_path = pepPlugin.config.claims_redirect_path || "";

            $scope.pluginConfig.require_id_token = pepPlugin.config.require_id_token;
            $scope.pluginConfig.uma_scope_expression = JSON.parse(pepPlugin.config.uma_scope_expression) || [];
            $scope.ruleScope = {};
            $scope.ruleOauthScope = {};
            setTimeout(function () {
              if ($scope.pluginConfig.uma_scope_expression && $scope.pluginConfig.uma_scope_expression.length > 0) {
                $scope.pluginConfig.uma_scope_expression.forEach(function (path, pIndex) {
                  path.conditions.forEach(function (cond, cIndex) {
                    var pRule = cond.scope_expression.rule;
                    var op = '';
                    if (pRule['and']) {
                      op = 'and'
                    } else if (pRule['or']) {
                      op = 'or'
                    } else if (pRule['!']) {
                      op = '!'
                    }

                    _repeat(pRule[op], op, 0);

                    function _repeat(rule, op, id) {
                      if (op == "!") {
                        rule = rule['or'];
                      }

                      $("input[name=hdScopeCount" + pIndex + cIndex + "]").val(id + 1);
                      rule.forEach(function (oRule, oRuleIndex) {
                        if (oRule['var'] == 0 || oRule['var']) {
                          if (!$scope.ruleScope["scope" + pIndex + cIndex + id]) {
                            $scope.ruleScope["scope" + pIndex + cIndex + id] = [];
                          }

                          $scope.ruleScope["scope" + pIndex + cIndex + id].push({text: cond.scope_expression.data[oRule['var']]});
                        }

                        if (rule.length - 1 == oRuleIndex) {
                          // show remove button
                          var removeBtn = " <button type=\"button\" class=\"btn btn-xs btn-danger\" data-add=\"rule\" data-ng-click=\"removeGroup('" + pIndex + cIndex + "', " + id + ")\"><i class=\"mdi mdi-close\"></i> Delete</button>";
                          if (id == 0) {
                            removeBtn = "";
                          }
                          // render template
                          var htmlRender = "<input type=\"radio\" value=\"or\" name=\"condition" + pIndex + cIndex + id + "\" " + (op == "or" ? "checked" : "") + ">or | " +
                            "<input type=\"radio\" value=\"and\" name=\"condition" + pIndex + cIndex + id + "\" " + (op == "and" ? "checked" : "") + ">and | " +
                            "<input type=\"radio\" value=\"!\" name=\"condition" + pIndex + cIndex + id + "\" " + (op == "!" ? "checked" : "") + ">not " +
                            "<button type=\"button\" class=\"btn btn-xs btn-success\" data-add=\"rule\" data-ng-click=\"addGroup('" + pIndex + cIndex + "', " + (id + 1) + ")\" name=\"btnAdd" + pIndex + cIndex + id + "\"><i class=\"mdi mdi-plus\"></i> Add Group</button> " +
                            removeBtn +
                            "<div class=\"form-group has-feedback\"> " +
                            "<input type=\"hidden\" value=\"{{ruleScope['scope" + pIndex + cIndex + id + "']}}\" name=\"hdScope" + pIndex + cIndex + id + "\" /> " +
                            "<tags-input min-length=\"1\" ng-model=\"ruleScope['scope" + pIndex + cIndex + id + "']\" required name=\"scope" + pIndex + cIndex + id + "\" id=\"scope" + pIndex + cIndex + id + "\" placeholder=\"Enter scopes\"></tags-input> " +
                            "</div>" +
                            "<div class=\"col-md-12\" id=\"dyScope" + pIndex + cIndex + (id + 1) + "\"></div>";

                          $("#dyScope" + pIndex + cIndex + id).append(htmlRender);
                          $compile(angular.element("#dyScope" + pIndex + cIndex + id).contents())($scope)
                          $("button[name=btnAdd" + pIndex + cIndex + id + "]").hide();
                          // end
                        }

                        if (oRule['and']) {
                          _repeat(oRule['and'], 'and', ++id);
                        } else if (oRule['or']) {
                          _repeat(oRule['or'], 'or', ++id);
                        } else if (oRule['!']) {
                          _repeat(oRule['!'], '!', ++id);
                        } else {
                          $("button[name=btnAdd" + pIndex + cIndex + id + "]").show();
                        }
                      });
                    }
                  });
                  path.pathIndex = pIndex;
                });
              }
            }, 500);
          } else {
            $scope.pluginConfig.isPEPEnabled = false;
            $scope.pluginConfig.uma_scope_expression = [];
            $scope.pluginConfig.deny_by_default = true;
            $scope.pluginConfig.require_id_token = true;
            $scope.pluginConfig.redirect_claim_gathering_url = false;
            $scope.pluginConfig.claims_redirect_path = "";
            setClaimPath()
          }
        } else {
          $scope.pluginConfig = {
            isPEPEnabled: $scope.pluginConfig.isPEPEnabled,
            deny_by_default: true,
            kong_proxy_url: '',
            redirect_claim_gathering_url: true,
            claims_redirect_path: '/claims_callback',
            claims_redirect_uri: '',
            oxd_url: $scope.globalInfo.oxdWeb,
            op_url: $scope.globalInfo.opHost,
            client_id: $scope.globalInfo.clientId,
            client_secret: $scope.globalInfo.clientSecret,
            authorization_redirect_path: '/callback',
            redirect_uris: '',
            logout_path: '/logout',
            post_logout_redirect_path_or_url: '/logout_redirect_uri',
            post_logout_redirect_uri: '',
            requested_scopes: ['openid', 'oxd', 'email', 'profile', 'uma_protection'],
            required_acrs: ['auth_ldap_server'],
            required_acrs_expression: [
              {
                path: "/??",
                conditions: [{
                  httpMethods: ["?"],
                  apply_auth: true,
                  required_acrs: ["auth_ldap_server"]
                }]
              }
            ],
            isACRExpEnabled: true,
            max_id_token_age_value: 60,
            max_id_token_auth_age_value: 60,
            max_id_token_age_type: 'minutes',
            max_id_token_auth_age_type: 'minutes',
            uma_scope_expression: [],
            require_id_token: true,
            custom_headers: [{
              header_name: 'http-kong-id-token-{*}',
              value: 'id_token',
              format: 'string',
              sep: ' ',
              iterate: true,
            }, {
              header_name: 'http-kong-userinfo-{*}',
              value: 'userinfo',
              format: 'string',
              sep: ' ',
              iterate: true,
            }, {
              header_name: 'http-kong-userinfo',
              value: 'userinfo',
              format: 'jwt',
              iterate: false,
              sep: ' ',
            }, {
              header_name: 'http-kong-id-token',
              value: 'id_token',
              format: 'jwt',
              iterate: false,
              sep: ' ',
            }]
          };
          setURLs();
        }

        /**
         * ----------------------------------------------------------------------
         * Functions
         * ----------------------------------------------------------------------
         */
        function getKongProxyURL() {
          var route = $scope.route;
          var protocol = route.protocols.indexOf("https") < 0 ? "http" : "https";
          var host = (route.hosts && route.hosts[0]) || "localhost";

          var port = '';
          $scope.info.configuration.proxy_listeners.forEach(function (v) {
            if (v.ssl) {
              port = v.port
            }
          });
          if (!port) {
            MessageService.error('SSL configuration not enabled. Please configured SSL in your kong proxy first.');
            return
          }
          $scope.pluginConfig.kong_proxy_url = (port === 443) ? protocol + "://" + host : protocol + "://" + host + ":" + port;
          if ($scope.isPluginAdded) {
            if (!$scope.pluginConfig.post_logout_redirect_path_or_url.startsWith('/')) {
              $scope.pluginConfig.post_logout_redirect_uri = $scope.pluginConfig.post_logout_redirect_path_or_url
              return
            }
          }
          $scope.pluginConfig.post_logout_redirect_uri = $scope.pluginConfig.kong_proxy_url + $scope.pluginConfig.post_logout_redirect_path_or_url;
        }

        function setURLs() {
          var route = $scope.route;
          var path = (route.paths && route.paths[0]) || "";
          $scope.pluginConfig.authorization_redirect_path = path + "/callback";
          $scope.pluginConfig.post_logout_redirect_path_or_url = path + "/logout_redirect_uri";
          $scope.pluginConfig.logout_path = path + "/logout";
          $scope.pluginConfig.claims_redirect_path = path + "/claims_callback";
        }

        function setClaimPath() {
          var route = $scope.route;
          var path = (route.paths && route.paths[0]) || "";
          $scope.pluginConfig.claims_redirect_path = path + "/claims_callback";
        }

        function addNewScope(scope) {
          if ($scope.opResponse.scopes_supported.indexOf(scope) > -1) {
            MessageService.error('Duplicate values not allowed!');
            return
          }
          $scope.opResponse.scopes_supported.push(angular.copy(scope));
          $scope.newScope = ''
        }

        function getDiscoveryResponse() {
          $scope.loading = true;
          PluginsService
            .getOPDiscoveryResponse({op_url: $scope.pluginConfig.op_url})
            .then(function (opRes) {
              $scope.opResponse = opRes.data;
              $scope.op_acr_values_supported = $scope.opResponse.acr_values_supported;
              $scope.opResponse.acr_values_supported = $scope.opResponse.acr_values_supported.map(function (acr) {
                return {
                  value: acr, level: Object.keys($scope.opResponse.auth_level_mapping).find(function (level) {
                    if ($scope.opResponse.auth_level_mapping[level].indexOf(acr) > -1) {
                      return true;
                    }
                  })
                }
              });
              $scope.opResponse.acr_values_supported.sort(function (a, b) {
                if (parseInt(a.level) > parseInt(b.level)) {
                  return -1;
                } else {
                  return 1;
                }
              })
            })
            .catch(function (error) {
              console.log(error);
              MessageService.error((error.data && error.data.message) || "Failed to get OP discovery response");
            })
            .finally(function () {
              $scope.loading = false;
            });
        }

        function managePlugin(fElement) {
          var isFormValid = true;
          if (fElement && fElement.$error && fElement.$error.required) {
            fElement.$error.required.forEach(function (o) {
              if (document.getElementById(o.$name)) {
                isFormValid = false;
              }
            });
          }

          if ($scope.pluginConfig.isPEPEnabled && !isFormValid) {
            MessageService.error("Please fill all the UMA PEP Expression fields marked in red");
            return false;
          }

          if ($scope.pluginConfig.isACRExpEnabled && !isFormValid) {
            MessageService.error("Please fill all the ACRs Expression Configuration fields marked in red");
            return false;
          }

          if ($scope.pluginConfig.isPEPEnabled && checkDuplicatePath()) {
            MessageService.error("PATH must be unique (but occurs more than one once).");
            return false;
          }

          if ($scope.pluginConfig.isPEPEnabled && checkDuplicateMethod()) {
            MessageService.error("HTTP method must be unique within the given PATH (but occurs more than one once).");
            return false;
          }

          var model;
          model = angular.copy($scope.pluginConfig);

          if ($scope.pluginConfig.isPEPEnabled && model.requested_scopes.indexOf('uma_protection') < 0) {
            MessageService.error("uma_protection scope is required for gluu-uma-pep plugin configuration.");
            return false;
          }

          var scopeExpression = makeExpression($scope.pluginConfig);
          if (scopeExpression && scopeExpression.length > 0) {
            model.uma_scope_expression = scopeExpression;
          } else {
            delete model.uma_scope_expression
          }

          if (model.isPEPEnabled && !model.uma_scope_expression) {
            MessageService.error("UMA scope expression is required");
            return;
          }

          if ($scope.pluginConfig.isACRExpEnabled) {
            model.required_acrs_expression = makeACRExpression($scope.pluginConfig);
          } else {
            delete model.required_acrs_expression
          }

          if (model.required_acrs_expression && model.required_acrs_expression.length > 0) {
            model.required_acrs = [];
            model.required_acrs_expression.forEach(function (path, pIndex) {
              path.conditions.forEach(function (cond, cIndex) {
                var apply_auth = angular.copy(cond.apply_auth);
                cond.no_auth = !cond.apply_auth;
                delete cond.apply_auth;
                if (!apply_auth) {
                  return
                }
                cond.required_acrs.forEach(function (acr) {
                  if (model.required_acrs.indexOf(acr) < 0) {
                    model.required_acrs.push(acr);
                  }
                })
              });
            });
          } else {
            delete model.required_acrs
          }


          if ($scope.openingModal) return;

          $scope.openingModal = true;
          setTimeout(function () {
            $scope.openingModal = false;
          }, 1000);

          var createConsumer = $uibModal.open({
            animation: true,
            ariaLabelledBy: 'modal-title',
            ariaDescribedBy: 'modal-body',
            templateUrl: 'js/app/plugins/comment-modal.html',
            controller: function ($scope, $rootScope, $log, $uibModalInstance, MessageService) {
              $scope.close = close;
              $scope.submit = submit;
              $scope.comment = "";

              function submit(valid) {
                if (!valid) {
                  return;
                }

                if (!$scope.comment) {
                  MessageService.error('Comment required!');
                  return
                }
                $uibModalInstance.close($scope.comment);
              }

              function close() {
                $uibModalInstance.dismiss();
              }
            },
            controllerAs: '$ctrl',
          });

          createConsumer.result.then(function (comment) {
            model.comment = comment;

            if ($scope.isPluginAdded) {
              updatePlugin(model)
            } else {
              addPlugin(model)
            }
          })
        }

        function addPlugin(model) {
          PluginsService
            .addOPClient({
              client_name: 'gg-openid-connect-client',
              op_host: model.op_url,
              oxd_url: model.oxd_url,
              redirect_uris: [model.kong_proxy_url + model.authorization_redirect_path],
              post_logout_redirect_uris: [model.post_logout_redirect_uri],
              claims_redirect_uri: [model.kong_proxy_url + model.claims_redirect_path],
              scope: model.requested_scopes,
              acr_values: model.required_acrs || null,
              route_id: $scope.route.id,
              comment: model.comment,
              uma_scope_expression: model.uma_scope_expression || [],
            })
            .then(function (response) {
              var opClient = response.data;
              var max_id_token_age = getSeconds(model.max_id_token_age_value, model.max_id_token_age_type);
              var max_id_token_auth_age = getSeconds(model.max_id_token_auth_age_value, model.max_id_token_auth_age_type);
              if (model.post_logout_redirect_uri.startsWith(model.kong_proxy_url)) {
                model.post_logout_redirect_path_or_url = model.post_logout_redirect_uri.replace(model.kong_proxy_url, '');
              } else {
                model.post_logout_redirect_path_or_url = model.post_logout_redirect_uri
              }
              var pluginModel = {
                name: 'gluu-openid-connect',
                route: {
                  id: $scope.route.id
                },
                tags: model.tags || null,
                config: {
                  oxd_id: opClient.oxd_id,
                  oxd_url: model.oxd_url,
                  client_id: opClient.client_id,
                  client_secret: opClient.client_secret,
                  op_url: model.op_url,
                  authorization_redirect_path: model.authorization_redirect_path,
                  logout_path: model.logout_path,
                  post_logout_redirect_path_or_url: model.post_logout_redirect_path_or_url,
                  requested_scopes: model.requested_scopes,
                  // required_acrs: model.required_acrs || null,
                  required_acrs_expression: (model.required_acrs_expression && JSON.stringify(model.required_acrs_expression)) || null,
                  max_id_token_age: max_id_token_age,
                  max_id_token_auth_age: max_id_token_auth_age,
                  custom_headers: model.custom_headers || []
                }
              };

              return new Promise(function (resolve, reject) {
                return PluginHelperService.addPlugin(
                  pluginModel,
                  function success(res) {
                    return resolve(opClient);
                  }, function (err) {
                    return reject(err);
                  });
              });
            })
            .then(function (opClient) {
              if (!model.isPEPEnabled) {
                MessageService.success('Gluu OpenID Connect Plugin added successfully!');
                $state.go("routes");
                return
              }

              // var uma_scope_expression = removeExtraScope(model.uma_scope_expression);
              var pepModel = {
                name: 'gluu-uma-pep',
                route: {
                  id: $scope.route.id
                },
                config: {
                  oxd_id: opClient.oxd_id,
                  client_id: opClient.client_id,
                  client_secret: opClient.client_secret,
                  op_url: model.op_url,
                  oxd_url: model.oxd_url,
                  uma_scope_expression: JSON.stringify(model.uma_scope_expression),
                  deny_by_default: model.deny_by_default || false,
                  require_id_token: model.require_id_token || false,
                  obtain_rpt: true,
                  redirect_claim_gathering_url: model.redirect_claim_gathering_url || false,
                  claims_redirect_path: model.claims_redirect_path,
                }
              };
              return PluginHelperService.addPlugin(pepModel,
                function success(res) {
                  $state.go("routes");
                  MessageService.success('Gluu OpenID Connect and UMA PEP Plugin added successfully!');
                }, function (err) {
                  return Promise.reject(err);
                });
            })
            .catch(function (error) {
              $scope.busy = false;
              $log.error("create plugin", error);
              console.log(error);
              if (error.data.body) {
                Object.keys(error.data.body).forEach(function (key) {
                  MessageService.error(key + " : " + error.data.body[key]);
                });
                return
              }
              MessageService.error("Failed!");
            });
        }

        function updatePlugin(model) {
          var max_id_token_age = getSeconds(model.max_id_token_age_value, model.max_id_token_age_type);
          var max_id_token_auth_age = getSeconds(model.max_id_token_auth_age_value, model.max_id_token_auth_age_type);

          PluginsService
            .updateOPClient({
              comment: model.comment,
              route_id: $scope.route.id,
              uma_scope_expression: model.uma_scope_expression || [],
              oxd_id: model.oxd_id,
              op_host: model.op_url,
              oxd_url: model.oxd_url,
              client_id: model.client_id,
              client_secret: model.client_secret,
              redirect_uris: [model.kong_proxy_url + model.authorization_redirect_path],
              post_logout_redirect_uris: [model.post_logout_redirect_uri],
              claims_redirect_uri: [model.kong_proxy_url + model.claims_redirect_path],
              scope: model.requested_scopes,
              acr_values: model.required_acrs || null,
              alreadyAddedUMAExpression: $scope.alreadyAddedUMAExpression || false,
            })
            .then(function (response) {
              var opClient = response.data;
              if (model.post_logout_redirect_uri.startsWith(model.kong_proxy_url)) {
                model.post_logout_redirect_path_or_url = model.post_logout_redirect_uri.replace(model.kong_proxy_url, '');
              } else {
                model.post_logout_redirect_path_or_url = model.post_logout_redirect_uri
              }
              var pluginModel = {
                name: 'gluu-openid-connect',
                route: {
                  id: $scope.route.id
                },
                config: {
                  oxd_id: opClient.oxd_id,
                  oxd_url: model.oxd_url,
                  client_id: opClient.client_id,
                  client_secret: opClient.client_secret,
                  op_url: model.op_url,
                  authorization_redirect_path: model.authorization_redirect_path,
                  logout_path: model.logout_path,
                  post_logout_redirect_path_or_url: model.post_logout_redirect_path_or_url,
                  requested_scopes: model.requested_scopes,
                  // required_acrs: model.required_acrs || null,
                  required_acrs_expression: (model.required_acrs_expression && JSON.stringify(model.required_acrs_expression)) || null,
                  max_id_token_age: max_id_token_age,
                  max_id_token_auth_age: max_id_token_auth_age,
                  custom_headers: model.custom_headers || [],
                }
              };

              if (model.tags) {
                pluginModel.tags = model.tags
              }

              return new Promise(function (resolve, reject) {
                return PluginHelperService.updatePlugin(model.openid_connect_id,
                  pluginModel,
                  function success(res) {
                    return resolve(model);
                  }, function (err) {
                    return reject(err);
                  });
              });
            })
            .then(function (opClient) {
              if (!model.isPEPEnabled) {
                MessageService.success('Gluu OpenID Connect Plugin update successfully!');
                $state.go("routes");
                return
              }

              // var uma_scope_expression = removeExtraScope(model.uma_scope_expression);
              var pepModel = {
                name: 'gluu-uma-pep',
                route: {
                  id: $scope.route.id
                },
                config: {
                  oxd_id: opClient.oxd_id,
                  client_id: opClient.client_id,
                  client_secret: opClient.client_secret,
                  op_url: model.op_url,
                  oxd_url: model.oxd_url,
                  uma_scope_expression: JSON.stringify(model.uma_scope_expression),
                  deny_by_default: model.deny_by_default || false,
                  require_id_token: model.require_id_token || false,
                  obtain_rpt: true,
                  redirect_claim_gathering_url: model.redirect_claim_gathering_url || false,
                  claims_redirect_path: model.claims_redirect_path,
                }
              };

              if (model.pepId) {
                return PluginHelperService.updatePlugin(model.pepId, pepModel,
                  success,
                  error);
              } else {
                return PluginHelperService.addPlugin(
                  pepModel,
                  success,
                  error);
              }

              function success(res, msg) {
                $state.go("routes");
                if (model.pepId) {
                  MessageService.success('Gluu OpenID Connect and UMA PEP Plugin updated successfully!');
                } else {
                  MessageService.success('Gluu OpenID Connect updated and UMA PEP Plugin added successfully!');
                }
              }

              function error(err) {
                return Promise.reject(err);
              }
            })
            .catch(function (error) {
              $scope.busy = false;
              $log.error("create plugin", error);
              console.log(error);
              if (error.data && error.data.body) {
                Object.keys(error.data.body).forEach(function (key) {
                  MessageService.error(key + " : " + error.data.body[key]);
                });
                return
              }
              MessageService.error("Failed!");
            });
        }

        function getSeconds(value, type) {
          if (type === 'seconds') {
            return value
          } else if (type === 'minutes') {
            return value * 60
          } else if (type === 'hours') {
            return value * 60 * 60
          } else if (type === 'days') {
            return value * 60 * 60 * 24
          }
        }

        function convertSeconds(seconds) {
          var value = seconds / (1 * 60 * 60 * 24);
          if (isInt(value)) {
            return {value: value, type: 'days'}
          }

          value = seconds / (1 * 60 * 60);
          if (isInt(value)) {
            return {value: value, type: 'hours'}
          }

          value = seconds / (1 * 60);
          if (isInt(value)) {
            return {value: value, type: 'minutes'}
          }

          value = seconds / 1;
          if (isInt(value)) {
            return {value: value, type: 'seconds'}
          }
        }

        function isInt(n) {
          return Number(n) === n && n % 1 === 0;
        }

        /**
         * Functions for UMA Expression
         */

        function removeGroup(parent, id) {
          $("#dyScope" + parent + id).html('');
          $("input[name=hdScopeCount" + parent + "]").val(id);
          $("button[name=btnAdd" + parent + (id - 1) + "]").show();
        }

        function addGroup(parent, id) {
          $("input[name=hdScopeCount" + parent + "]").val(id + 1);
          $("button[name=btnAdd" + parent + (id - 1) + "]").hide();
          var htmlRender = "<div class=\"col-md-12\">" +
            "<input type=\"radio\" value=\"or\" name=\"condition" + parent + id + "\" checked>or | <input type=\"radio\" value=\"and\" name=\"condition" + parent + id + "\">and | <input type=\"radio\" value=\"!\" name=\"condition" + parent + id + "\">not" +
            "<button type=\"button\" class=\"btn btn-xs btn-success\" data-add=\"rule\" data-ng-click=\"addGroup('" + parent + "', " + (id + 1) + ")\" name=\"btnAdd" + parent + id + "\"><i class=\"mdi mdi-plus\"></i> Add Group</button> " +
            "<button type=\"button\" class=\"btn btn-xs btn-danger\" data-add=\"rule\" data-ng-click=\"removeGroup('" + parent + "', " + id + ")\"><i class=\"mdi mdi-close\"></i> Delete</button>" +
            "<input type=\"hidden\" value=\"{{cond['scopes" + parent + id + "']}}\" name=\"hdScope" + parent + id + "\" />" +
            "<div class=\"form-group has-feedback\">" +
            "<tags-input min-length=\"1\" type=\"url\" required ng-model=\"cond['scopes" + parent + id + "']\" name=\"scope" + id + "\" id=\"scopes{{$parent.$index}}{{$index}}\" placeholder=\"Enter scopes\"> </tags-input>" +
            "</div>" +
            "<div class=\"col-md-12\" id=\"dyScope" + parent + (id + 1) + "\"></div>" +
            "</div>";
          $("#dyScope" + parent + id).append(htmlRender);
          $compile(angular.element("#dyScope" + parent + id).contents())($scope)
        }

        function addNewCondition(pIndex) {
          $scope.pluginConfig.uma_scope_expression[pIndex].conditions.push(
            {
              httpMethods: [{text: 'GET'}],
              scope_expression: [],
              ticketScopes: []
            });

          if ($scope.isPluginAdded) {
            var parent = pIndex + '' + ($scope.pluginConfig.uma_scope_expression[pIndex].conditions.length - 1);
            var id = 0;
            setTimeout(function () {
              var htmlRender = "<input type=\"radio\" value=\"or\" name=\"condition" + parent + "0\" checked>or | <input type=\"radio\" value=\"and\" name=\"condition" + parent + "0\">and | <input type=\"radio\" value=\"!\" name=\"condition" + parent + "0\">not " +
                "<button type=\"button\" class=\"btn btn-xs btn-success\" data-add=\"rule\" data-ng-click=\"addGroup('" + parent + "',1)\" name=\"btnAdd" + parent + id + "\"><i class=\"mdi mdi-plus\"></i> Add Group </button>" +
                "<input type=\"hidden\" value=\"{{cond['scopes' + " + parent + " + '0']}}\" name=\"hdScope" + parent + "0\"/>" +
                "<div class=\"form-group has-feedback\">" +
                "<tags-input min-length=\"1\" ng-model=\"cond['scopes' + " + parent + " + '0']\" required name=\"scope" + parent + "0\" id=\"scopes" + parent + "\" placeholder=\"Enter scopes\"></tags-input>" +
                "</div>" +
                "<div class=\"col-md-12\" id=\"dyScope" + parent + (id + 1) + "\"></div>";

              $("#dyScope" + parent + '' + id).append(htmlRender);
              $compile(angular.element("#dyScope" + parent + id).contents())($scope)
            });
          }
        }

        function showPathPossibilities() {
          $uibModal.open({
            animation: true,
            templateUrl: 'js/app/plugins/modals/path-possibilities-modal.html',
            size: 'lg',
            controller: ['$uibModalInstance', '$scope', function ($uibModalInstance, $scope) {
              $scope.paths = [
                {
                  path: '/??',
                  allow: ['/folder/file.ext', '/folder/file2', 'Allow all the paths'],
                  deny: []
                }, {
                  path: '/folder/file.ext',
                  allow: ['/folder/file.ext'],
                  deny: ['/folder/file']
                }, {
                  path: '/folder/?/file',
                  allow: ['/folder/123/file', '/folder/xxx/file'],
                  deny: []
                }, {
                  path: '/path/??',
                  allow: ['/path/', '/path/xxx', '/path/xxx/yyy/file'],
                  deny: ['/path - Need slash at last']
                }, {
                  path: '/path/??/image.jpg',
                  allow: ['/path/one/two/image.jpg', '/path/image.jpg'],
                  deny: []
                }, {
                  path: '/path/?/image.jpg',
                  allow: ['/path/xxx/image.jpg - ? has higher priority than ??'],
                  deny: []
                }, {
                  path: '/path/{abc|xyz}/image.jpg',
                  allow: ['/path/abc/image.jpg', '/path/xyz/image.jpg'],
                  deny: []
                }, {
                  path: '/users/?/{todos|photos}',
                  allow: ['/users/123/todos', '/users/xxx/photos'],
                  deny: []
                }, {
                  path: '/users/?/{todos|photos}/?',
                  allow: ['/users/123/todos/', '/users/123/todos/321', '/users/123/photos/321'],
                  deny: []
                }
              ]
            }],
          }).result.then(function (result) {
          });
        }

        function showResourceJSON() {
          var model = angular.copy($scope.pluginConfig);
          var uma_scope_expression = makeExpression(model);
          if (uma_scope_expression == null) {
            return
          }
          if (!model) {
            return false;
          }

          $uibModal.open({
            animation: true,
            templateUrl: 'js/app/plugins/modals/show-uma-scope-json-modal.html',
            size: 'lg',
            controller: ['$uibModalInstance', '$scope', 'uma_scope_expression', function ($uibModalInstance, $scope, uma_scope_expression) {
              $scope.uma_scope_expression = uma_scope_expression;
            }],
            resolve: {
              uma_scope_expression: function () {
                return uma_scope_expression;
              }
            }
          }).result.then(function (result) {
          });
        }

        function showACRExpressionJSON() {
          var model = angular.copy($scope.pluginConfig);
          var acr_expression = makeACRExpression(model);

          if (acr_expression == null) {
            return
          }
          if (!model) {
            return false;
          }

          acr_expression.forEach(function (path, pIndex) {
            path.conditions.forEach(function (cond, cIndex) {
              var apply_auth = angular.copy(cond.apply_auth);
              cond.no_auth = !cond.apply_auth;
              delete cond.apply_auth;
            });
          });

          $uibModal.open({
            animation: true,
            templateUrl: 'js/app/plugins/modals/show-acr-expression-json-modal.html',
            size: 'lg',
            controller: ['$uibModalInstance', '$scope', 'acr_expression', function ($uibModalInstance, $scope, acr_expression) {
              $scope.acr_expression = acr_expression;
            }],
            resolve: {
              acr_expression: function () {
                return acr_expression;
              }
            }
          }).result.then(function (result) {
          });
        }


        function addNewPath() {
          $scope.pluginConfig.uma_scope_expression.push({
            path: ($scope.route.paths && $scope.route.paths[0]) || '',
            pathIndex: $scope.pluginConfig.uma_scope_expression.length,
            conditions: [
              {
                httpMethods: [{text: 'GET'}],
                scope_expression: [],
                ticketScopes: []
              }
            ]
          });

          if ($scope.isPluginAdded) {
            var parent = $scope.pluginConfig.uma_scope_expression.length - 1 + '0';
            var id = 0;
            setTimeout(function () {
              var htmlRender = "<input type=\"radio\" value=\"or\" name=\"condition" + parent + "0\" checked>or | <input type=\"radio\" value=\"and\" name=\"condition" + parent + "0\">and | <input type=\"radio\" value=\"!\" name=\"condition" + parent + "0\">not" +
                "<button type=\"button\" class=\"btn btn-xs btn-success\" data-add=\"rule\" data-ng-click=\"addGroup('" + parent + "',1)\" name=\"btnAdd" + parent + id + "\"><i class=\"mdi mdi-plus\"></i> Add Group </button>" +
                "<input type=\"hidden\" value=\"{{cond['scopes' + " + parent + " + '0']}}\" name=\"hdScope" + parent + "0\"/>" +
                "<div class=\"form-group has-feedback\">" +
                "<tags-input min-length=\"1\" ng-model=\"cond['scopes' + " + parent + " + '0']\" required name=\"scope" + parent + "0\" id=\"scopes" + parent + "\" placeholder=\"Enter scopes\"> </tags-input>" +
                "</div>" +
                "<div class=\"col-md-12\" id=\"dyScope" + parent + (id + 1) + "\"></div>" +
                "</div>";
              $("#dyScope" + parent + '' + id).append(htmlRender);
              $compile(angular.element("#dyScope" + parent + id).contents())($scope)
            });
          }
        }

        function addACRNewPath() {
          $scope.pluginConfig.required_acrs_expression.push({
            path: "/??",
            conditions: [{
              httpMethods: ["?"],
              apply_auth: true,
              required_acrs: ["auth_ldap_server"]
            }]
          });
        }

        function addACRNewCondition(pIndex) {
          $scope.pluginConfig.required_acrs_expression[pIndex].conditions.push(
            {
              httpMethods: ["?"],
              apply_auth: true,
              required_acrs: ["auth_ldap_server"]
            }
          );
        }

        function loadMethods(query) {
          var arr = ['GET', 'POST', 'DELETE', 'PUT', 'PATCH', 'OPTIONS', 'CONNECT', 'TRACE', 'HEAD', '?'];
          arr = arr.filter(function (o) {
            return o.indexOf(query.toUpperCase()) >= 0;
          });
          return arr;
        }

        function loadACRMethods(query) {
          var arr = $scope.op_acr_values_supported;
          arr = arr.filter(function (o) {
            return o.indexOf(query.toLowerCase()) >= 0;
          });
          return arr;
        }

        function loadScopes(query) {
          return [];
        }

        function makeExpression(data) {
          try {
            var model = angular.copy(data);
            var dIndex = 0;
            var sData = [];
            model.uma_scope_expression.forEach(function (path, pIndex) {
              path.conditions.forEach(function (cond, cIndex) {
                dIndex = 0;
                sData = [];
                pIndex = path.pathIndex;
                var str = '{%s}';
                for (var i = 0; i < parseInt($("input[name=hdScopeCount" + pIndex + cIndex + "]").val()); i++) {
                  var op = $("input[name=condition" + pIndex + cIndex + i + "]:checked").val();
                  var scopes = JSON.parse($("input[name=hdScope" + pIndex + cIndex + i + "]").val()).map(function (o) {
                    sData.push(o.text);
                    return {"var": dIndex++};
                  });
                  var s = "";
                  scopes.forEach(function (item) {
                    s += JSON.stringify(item) + ","
                  });

                  if (op == '!') {
                    str = str.replace('%s', "\"" + op + "\":{\"or\":[" + s + " {%s}]}");
                  } else {
                    str = str.replace('%s', "\"" + op + "\":[" + s + " {%s}]");
                  }

                  if (!!cond["scopes" + pIndex + cIndex + i]) {
                    delete cond["scopes" + pIndex + cIndex + i]
                  }
                }

                cond.httpMethods = cond.httpMethods.map(function (o) {
                  return o.text;
                });
                str = str.replace(', {%s}', '');
                cond.scope_expression = {rule: JSON.parse(str), data: angular.copy(sData)};

                if (cond.ticketScopes && cond.ticketScopes.length > 0) {
                  cond.ticketScopes = cond.ticketScopes.map(function (o) {
                    return o.text;
                  });
                } else {
                  delete cond.ticketScopes;
                }
              });
              delete path.pathIndex
            });
            return model.uma_scope_expression;
          } catch (e) {
            MessageService.error("Invalid UMA scope expression");
            return null;
          }
        }

        function makeACRExpression(data) {
          try {
            var model = angular.copy(data);
            model.required_acrs_expression.forEach(function (path, pIndex) {
              path.conditions.forEach(function (cond, cIndex) {
                cond.httpMethods = cond.httpMethods.map(function (o) {
                  return o.text;
                });
              });
            });
            return model.required_acrs_expression;
          } catch (e) {
            MessageService.error("Invalid acr expression");
            return null;
          }
        }

        function checkDuplicateMethod() {
          var model = angular.copy($scope.pluginConfig);
          var methodFlag = false;

          model.uma_scope_expression.forEach(function (path, pIndex) {
            var methods = [];
            path.conditions.forEach(function (cond, cIndex) {
              if (!cond.httpMethods) {
                return
              }
              cond.httpMethods.forEach(function (m) {
                if (methods.indexOf(m.text) >= 0) {
                  methodFlag = true
                }
                methods.push(m.text);
              })
            });
          });
          return methodFlag;
        }

        function checkDuplicatePath() {
          var model = angular.copy($scope.pluginConfig);
          var pathFlag = false;
          var paths = [];
          model.uma_scope_expression.forEach(function (path, pIndex) {
            if (!path.path) {
              return
            }
            if (paths.indexOf(path.path) >= 0) {
              pathFlag = true
            }
            paths.push(path.path);
          });
          return pathFlag;
        }

        function removeExtraScope(expression) {
          return expression.map(function (path) {
            path.conditions.map(function (condition) {
              delete condition.scope_expression;
              return condition;
            });
            return path;
          })
        }

        function openCreateConsumerModal() {
          if ($scope.openingModal) return;

          $scope.openingModal = true;
          setTimeout(function () {
            $scope.openingModal = false;
          }, 1000);

          var createConsumer = $uibModal.open({
            animation: true,
            ariaLabelledBy: 'modal-title',
            ariaDescribedBy: 'modal-body',
            templateUrl: 'js/app/plugins/create-anonymous-consumer-modal.html',
            controller: function ($scope, $rootScope, $log, $uibModalInstance, MessageService, ConsumerModel) {

              $scope.consumer = {
                username: 'anonymous',
                custom_id: 'anonymous'
              };

              $scope.close = close;
              $scope.submit = submit;

              function submit(valid) {
                if (!valid) {
                  return
                }

                $scope.errors = {};

                var data = _.cloneDeep($scope.consumer);
                if (!data.custom_id) {
                  delete data.custom_id;
                }

                if (!data.username) {
                  delete data.username;
                }

                ConsumerModel.create(data)
                  .then(function (res) {
                    MessageService.success("Consumer created successfully!");
                    $rootScope.$broadcast('consumer.created', res.data);
                    $uibModalInstance.close(res.data);
                  })
                  .catch(function (err) {
                    $log.error("Failed to create consumer", err);
                    console.log(err);
                    var errorMessage = (err.data && err.data.body && err.data.body.message) || "Error";
                    MessageService.error(errorMessage);
                  });
              }

              function close() {
                $uibModalInstance.dismiss()
              }
            },
            controllerAs: '$ctrl',
          });

          createConsumer.result.then(function (consumer) {
            $scope.pluginConfig.anonymous = consumer.id;
          })
        }

        function openConsumerListModal() {
          if ($scope.openingModal) return;

          $scope.openingModal = true;
          setTimeout(function () {
            $scope.openingModal = false;
          }, 1000);

          var createConsumer = $uibModal.open({
            animation: true,
            ariaLabelledBy: 'modal-title',
            ariaDescribedBy: 'modal-body',
            templateUrl: 'js/app/plugins/consumer-list-modal.html',
            controller: function ($scope, $rootScope, $log, $uibModalInstance, MessageService, ConsumerModel, _consumers) {
              $scope.consumers = (_consumers && _consumers.data && _consumers.data.data) || [];
              $scope.close = close;

              function close() {
                $uibModalInstance.dismiss()
              }
            },
            resolve: {
              _consumers: [
                'ConsumerService',
                function resolve(ConsumerService) {
                  return ConsumerService.query()
                }
              ]
            },
            controllerAs: '$ctrl',
          });
        }

        function authSwitchClicked(cond) {
          if (!cond.apply_auth && cond.required_acrs) {
            delete cond.required_acrs
          } else {
            cond.required_acrs = ['auth_ldap_server']
          }
        }

        function addCustomHeader() {
          if (!$scope.pluginConfig.custom_headers || $scope.pluginConfig.custom_headers.length <= 0) {
            $scope.pluginConfig.custom_headers = []
          }
          $scope.pluginConfig.custom_headers.push({
            header_name: 'http-kong-custom',
            value: 'any_value',
            format: 'string',
            iterate: false,
            sep: ' ',
          })
        }

        function showCustomHeadersGuide() {
          $uibModal.open({
            animation: true,
            templateUrl: 'js/app/plugins/modals/custom-headers-guide.html',
            size: 'lg',
            controller: ['$uibModalInstance', '$scope', function ($uibModalInstance, $scope) {

            }],
          }).result.then(function (result) {
          });
        }

        // init
        $scope.getDiscoveryResponse();
        $scope.getKongProxyURL();
      }
    ]);
}());
