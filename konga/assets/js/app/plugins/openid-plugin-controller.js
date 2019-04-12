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
        $scope.getKongProxyURL = getKongProxyURL;

        $scope.addNewCondition = addNewCondition;
        $scope.addNewPath = addNewPath;
        $scope.showResourceJSON = showResourceJSON;
        $scope.managePlugin = managePlugin;
        $scope.loadMethods = loadMethods;
        $scope.loadScopes = loadScopes;
        $scope.addGroup = addGroup;
        $scope.removeGroup = removeGroup;
        $scope.openCreateConsumerModal = openCreateConsumerModal;
        $scope.openConsumerListModal = openConsumerListModal;

        $scope.pluginConfig = {};

        $scope.isPluginAdded = false;
        $scope.oidcPlugin = {};
        $scope.plugins.forEach(function (o) {
          if (o.name === "gluu-openid-connect") {
            $scope.oidcPlugin = o;
            $scope.isPluginAdded = true;
          }
        });

        if ($scope.isPluginAdded) {
          $scope.pluginConfig = $scope.oidcPlugin.config;
          PluginsService
            .getOAuthClient($scope.pluginConfig.oxd_id)
            .then(function (response) {
              $scope.dbData = response.data.data;
              $scope.pluginConfig.max_id_token_age_value = $scope.dbData.max_id_token_age.value;
              $scope.pluginConfig.max_id_token_age_type = $scope.dbData.max_id_token_age.type;
              $scope.pluginConfig.max_id_token_auth_age_value = $scope.dbData.max_id_token_auth_age.value;
              $scope.pluginConfig.max_id_token_auth_age_type = $scope.dbData.max_id_token_auth_age.type;
            })
            .catch(function (error) {
              console.log(error);
              MessageService.error((error.data && error.data.message) || "Failed to get Client details");
            });
        } else {
          $scope.pluginConfig = {
            isPEPEnabled: true,
            deny_by_default: true,
            kong_proxy_url: '',
            oxd_url: $scope.globalInfo.oxdWeb,
            op_url: $scope.globalInfo.opHost,
            client_id: $scope.globalInfo.clientId,
            client_secret: $scope.globalInfo.clientSecret,
            authorization_redirect_path: '/callback',
            authorization_redirect_uri: '',
            logout_path: '/logout',
            post_logout_redirect_path_or_url: '/logout_redirect_uri',
            post_logout_redirect_uri: '',
            requested_scopes: ['openid', 'oxd', 'email', 'profile'],
            required_acrs: ['auth_ldap_server', 'u2f', 'otp'],
            max_id_token_age_value: 60,
            max_id_token_auth_age_value: 60,
            max_id_token_age_type: 'seconds',
            max_id_token_auth_age_type: 'seconds',
            uma_scope_expression: [],
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
        }

        function setURLs() {
          var route = $scope.route;
          var path = (route.paths && route.paths[0]) || "";
          $scope.pluginConfig.authorization_redirect_path = path + "/callback";
          $scope.pluginConfig.post_logout_redirect_path_or_url = path + "/logout_redirect_uri";
          $scope.pluginConfig.logout_path = path + "/logout";
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
              $scope.opResponse = opRes.data
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
            MessageService.error("Please fill all the fields marked in red");
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

          if (!$scope.isPluginAdded) {
            model = angular.copy($scope.pluginConfig);
            var scopeExpression = makeExpression($scope.pluginConfig);
            if (scopeExpression && scopeExpression .length > 0) {
              model.uma_scope_expression = scopeExpression ;
            } else {
              delete model.uma_scope_expression
            }

            if (model.isPEPEnabled && !model.uma_scope_expression) {
              MessageService.error("UMA scope expression is required");
              return;
            }
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

              function submit() {
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
            $scope.pluginConfig.comment = comment;

            if ($scope.isPluginAdded) {
              updatePlugin()
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
              authorization_redirect_uri: model.kong_proxy_url + model.authorization_redirect_path,
              post_logout_redirect_uri: model.kong_proxy_url + model.post_logout_redirect_path_or_url,
              scope: model.requested_scopes,
              acr_values: model.required_acrs,
              route_id: $scope.route.id,
              comment: model.comment,
              max_id_token_age_value: model.max_id_token_age_value,
              max_id_token_age_type: model.max_id_token_age_type,
              max_id_token_auth_age_value: model.max_id_token_auth_age_value,
              max_id_token_auth_age_type: model.max_id_token_auth_age_type,
            })
            .then(function (response) {
              var opClient = response.data;
              var max_id_token_age =  getSeconds(model.max_id_token_age_value, model.max_id_token_age_type);
              var max_id_token_auth_age =  getSeconds(model.max_id_token_auth_age_value, model.max_id_token_auth_age_type);
              var pluginModel = {
                name: 'gluu-openid-connect',
                route_id: $scope.route.id,
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
                  required_acrs: model.required_acrs,
                  max_id_token_age: max_id_token_age,
                  max_id_token_auth_age: max_id_token_auth_age,
                }
              };
              return new Promise(function (resolve, reject) {
                return PluginHelperService.addPlugin(
                  pluginModel,
                  function success(res) {
                    return resolve(res);
                  }, function (err) {
                    return reject(err);
                  });
              });
            })
            .then(function (res) {
              $state.go("routes");
              MessageService.success('Plugin added successfully!');
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

        function updatePlugin() {
          var model = angular.copy($scope.pluginConfig);
          var extraData = $scope.dbData;
          var max_id_token_age =  getSeconds(model.max_id_token_age_value, model.max_id_token_age_type);
          var max_id_token_auth_age =  getSeconds(model.max_id_token_auth_age_value, model.max_id_token_auth_age_type);

          extraData.comments.push({commentDescription: model.comment, commentDate: Date.now()});
          extraData.max_id_token_age.value = model.max_id_token_age_value;
          extraData.max_id_token_age.type = model.max_id_token_age_type;
          extraData.max_id_token_auth_age.value = model.max_id_token_auth_age_value;
          extraData.max_id_token_auth_age.type = model.max_id_token_auth_age_type;

          PluginsService
            .updateOPClient({
              oxd_id: model.oxd_id,
              op_host: model.op_url,
              oxd_url: model.oxd_url,
              client_id: model.client_id,
              client_secret: model.client_secret,
              authorization_redirect_uri: model.kong_proxy_url + model.authorization_redirect_path,
              post_logout_redirect_uri: model.kong_proxy_url + model.post_logout_redirect_path_or_url,
              scope: model.requested_scopes,
              acr_values: model.required_acrs,
              extraData: extraData
            })
            .then(function (response) {
              var opClient = response.data;
              var pluginModel = {
                name: 'gluu-openid-connect',
                route_id: $scope.route.id,
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
                  required_acrs: model.required_acrs,
                  max_id_token_age: max_id_token_age,
                  max_id_token_auth_age: max_id_token_auth_age,
                }
              };
              return new Promise(function (resolve, reject) {
                return PluginHelperService.updatePlugin($scope.oidcPlugin.id,
                  pluginModel,
                  function success(res) {
                    return resolve(res);
                  }, function (err) {
                    return reject(err);
                  });
              });
            })
            .then(function (res) {
              $state.go("routes");
              MessageService.success('Plugin added successfully!');
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

        function getSeconds(value, type) {
          if (type === 'seconds') {
            return value
          } else if(type === 'minutes') {
            return value * 60
          } else if (type === 'hours') {
            return value * 60 * 60
          } else if (type === 'days') {
            return value * 60 * 60 * 24
          }
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
            "<tags-input type=\"url\" required ng-model=\"cond['scopes" + parent + id + "']\" name=\"scope" + id + "\" id=\"scopes{{$parent.$index}}{{$index}}\" placeholder=\"Enter scopes\"> </tags-input>" +
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
                "<tags-input ng-model=\"cond['scopes' + " + parent + " + '0']\" required name=\"scope" + parent + "0\" id=\"scopes" + parent + "\" placeholder=\"Enter scopes\"></tags-input>" +
                "</div>" +
                "<div class=\"col-md-12\" id=\"dyScope" + parent + (id + 1) + "\"></div>";

              $("#dyScope" + parent + '' + id).append(htmlRender);
              $compile(angular.element("#dyScope" + parent + id).contents())($scope)
            });
          }
        }

        function showResourceJSON() {
          var model = angular.copy($scope.pluginConfig);
          model.config.uma_scope_expression = makeExpression(model);
          if (model.config.uma_scope_expression == null) {
            return
          }
          if (!model) {
            return false;
          }

          $uibModal.open({
            animation: true,
            templateUrl: 'js/app/plugins/modals/show-uma-scope-json-modal.html',
            size: 'lg',
            controller: ['$uibModalInstance', '$scope', 'pluginConfig', ShowScriptController],
            resolve: {
              pluginConfig: function () {
                return model;
              }
            }
          }).result.then(function (result) {
          });
        }

        function ShowScriptController($uibModalInstance, $scope, pluginConfig) {
          $scope.model = angular.copy(pluginConfig);
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
                "<tags-input ng-model=\"cond['scopes' + " + parent + " + '0']\" required name=\"scope" + parent + "0\" id=\"scopes" + parent + "\" placeholder=\"Enter scopes\"> </tags-input>" +
                "</div>" +
                "<div class=\"col-md-12\" id=\"dyScope" + parent + (id + 1) + "\"></div>" +
                "</div>";
              $("#dyScope" + parent + '' + id).append(htmlRender);
              $compile(angular.element("#dyScope" + parent + id).contents())($scope)
            });
          }
        }

        function loadMethods(query) {
          var arr = ['GET', 'POST', 'DELETE', 'PUT', 'PATCH'];
          arr = arr.filter(function (o) {
            return o.indexOf(query.toUpperCase()) >= 0;
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

        // init
        $scope.getDiscoveryResponse();
        $scope.getKongProxyURL();
      }
    ]);
}());