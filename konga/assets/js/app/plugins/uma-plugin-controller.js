(function () {
  'use strict';

  angular.module('frontend.plugins')
    .controller('UMAPluginController', [
      '_', '$scope', '$log', '$state', 'PluginsService', 'MessageService',
      '$uibModal', 'DialogService', 'PluginModel', 'ListConfig', 'UserService', 'PluginHelperService', '_context_name', '_context_data', '_plugins', '$compile', 'InfoService', '$localStorage',
      function controller(_, $scope, $log, $state, PluginsService, MessageService,
                          $uibModal, DialogService, PluginModel, ListConfig, UserService, PluginHelperService, _context_name, _context_data, _plugins, $compile, InfoService, $localStorage) {
        $scope.globalInfo = $localStorage.credentials.user;
        $scope.context_data = (_context_data && _context_data.data) || null;
        $scope.context_name = _context_name || null;
        $scope.context_upstream = '';
        $scope.plugins = _plugins.data.data;
        $scope.umaPlugin = null;
        $scope.addNewCondition = addNewCondition;
        $scope.addNewPath = addNewPath;
        $scope.showResourceJSON = showResourceJSON;
        $scope.managePlugin = managePlugin;
        $scope.loadMethods = loadMethods;
        $scope.loadScopes = loadScopes;
        $scope.addGroup = addGroup;
        $scope.removeGroup = removeGroup;
        $scope.fetchData = fetchData;
        $scope.openCreateConsumerModal = openCreateConsumerModal;
        $scope.openConsumerListModal = openConsumerListModal;
        $scope.showPathPossibilities = showPathPossibilities;
        $scope.passCredentials = ['pass', 'hide', 'phantom_token'];

        if (_context_name == 'service') {
          $scope.context_upstream = $scope.context_data.protocol + "://" + $scope.context_data.host;
        } else if (_context_name == 'route') {
          $scope.context_upstream = $scope.context_data.protocols[0] + "://" + (($scope.context_data.hosts && $scope.context_data.hosts[0]) || ($scope.context_data.paths && $scope.context_data.paths[0]) || ($scope.context_data['methods'] && $scope.context_data['methods'][0]));
        } else if (_context_name == 'api') {
          $scope.context_upstream = $scope.context_data.upstream_url;
        }

        $scope.modelPlugin = {
          isPEPEnabled: true,
          config: {
            oxd_url: $scope.globalInfo.oxdWeb,
            op_url: $scope.globalInfo.opHost,
            uma_scope_expression: [],
            ignore_scope: false,
            deny_by_default: true,
            pass_credentials: 'pass'
          }
        };

        if ($scope.context_name) {
          $scope.modelPlugin[$scope.context_name] = {
            id: $scope.context_data.id
          }
        } else {
          $scope.plugins = $scope.plugins.filter(function (item) {
            return (!((item.service && item.service.id) || (item.route && item.route.id)))
          });
        }

        $scope.isPluginAdded = false;
        var pepPlugin, authPlugin;
        $scope.plugins.forEach(function (o) {
          if (o.name == "gluu-uma-auth") {
            authPlugin = o;
          }

          if (o.name == "gluu-uma-pep") {
            pepPlugin = o;
          }
        });

        if (authPlugin) {
          $scope.modelPlugin = authPlugin;
          $scope.modelPlugin.authId = authPlugin.id;
          $scope.modelPlugin.isPEPEnabled = false;
          $scope.isPluginAdded = true;
        }

        if (pepPlugin) {
          $scope.modelPlugin.isPEPEnabled = true;
          $scope.modelPlugin.pepId = pepPlugin.id;
          $scope.modelPlugin.config.deny_by_default = pepPlugin.config.deny_by_default;
          $scope.modelPlugin.isPEPEnabled = true;
          $scope.isPluginAdded = true;
          $scope.ruleScope = {};
          $scope.ruleOauthScope = {};
          $scope.modelPlugin.config.uma_scope_expression = JSON.parse(pepPlugin.config.uma_scope_expression) || [];
          setTimeout(function () {
            if ($scope.modelPlugin.config.uma_scope_expression && $scope.modelPlugin.config.uma_scope_expression.length > 0) {
              $scope.modelPlugin.config.uma_scope_expression.forEach(function (path, pIndex) {
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
        }

        /**
         * ----------------------------------------------------------------------
         * Functions
         * ----------------------------------------------------------------------
         */
        function fetchData() {
          InfoService
            .getInfo()
            .then(function (resp) {
              $scope.info = resp.data;
              if (!$scope.context_name) {
                $scope.context_upstream = "http://" + $scope.info.hostname + ":" + $scope.info.configuration.proxy_listeners[0].port;
              }
              $log.debug("DashboardController:fetchData:info", $scope.info);
            })
        }

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
          $scope.modelPlugin.config.uma_scope_expression[pIndex].conditions.push(
            {
              httpMethods: [{text: 'GET'}],
              scope_expression: [],
              ticketScopes: []
            });

          if ($scope.isPluginAdded) {
            var parent = pIndex + '' + ($scope.modelPlugin.config.uma_scope_expression[pIndex].conditions.length - 1);
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

        function showResourceJSON() {
          var model = angular.copy($scope.modelPlugin);
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

        function addNewPath() {
          $scope.modelPlugin.config.uma_scope_expression.push({
            path: '',
            pathIndex: $scope.modelPlugin.config.uma_scope_expression.length,
            conditions: [
              {
                httpMethods: [{text: 'GET'}],
                scope_expression: [],
                ticketScopes: []
              }
            ]
          });

          if ($scope.isPluginAdded) {
            var parent = $scope.modelPlugin.config.uma_scope_expression.length - 1 + '0';
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

        function managePlugin(fElement) {
          var isFormValid = true;
          if (fElement && fElement.$error && fElement.$error.required) {
            fElement.$error.required.forEach(function (o) {
              if (document.getElementById(o.$name)) {
                isFormValid = false;
              }
            });
          }

          if (!$scope.modelPlugin.config.anonymous) {
            MessageService.error("Anonymous consumer is required");
            return false;
          }

          if (!isFormValid) {
            MessageService.error("Please fill all the fields marked in red");
            return false;
          }

          if (checkDuplicatePath()) {
            MessageService.error("PATH must be unique (but occurs more than one once).");
            return false;
          }

          if (checkDuplicateMethod()) {
            MessageService.error("HTTP method must be unique within the given PATH (but occurs more than one once).");
            return false;
          }

          if ($scope.isPluginAdded) {
            updatePlugin();
          } else {
            addPlugin();
          }
        }

        function addPlugin() {
          var model = angular.copy($scope.modelPlugin);
          var uma_scope_expression = makeExpression($scope.modelPlugin);
          if (uma_scope_expression && uma_scope_expression.length > 0) {
            model.config.uma_scope_expression = JSON.stringify(uma_scope_expression);
          } else {
            return MessageService.error('UMA Scope Expression is required');
          }
          PluginsService
            .registerClientAndResources({
              oxd_id: model.config.oxd_id || null,
              client_id: model.config.client_id || null,
              client_secret: model.config.client_secret || null,
              uma_scope_expression: uma_scope_expression,
              client_name: 'gluu-uma-client',
              op_host: model.config.op_url,
              oxd_url: model.config.oxd_url
            })
            .then(function (response) {
              var oauthClient = response.data;
              var authModel = {
                name: 'gluu-uma-auth',
                tags: model.tags || null,
                config: {
                  oxd_id: oauthClient.oxd_id,
                  client_id: oauthClient.client_id,
                  client_secret: oauthClient.client_secret,
                  op_url: model.config.op_url,
                  oxd_url: model.config.oxd_url,
                  anonymous: model.config.anonymous,
                  pass_credentials: model.config.pass_credentials
                }
              };
              if ($scope.context_name) {
                authModel[$scope.context_name] ={
                  id: $scope.context_data.id
                };
              }
              return new Promise(function (resolve, reject) {
                PluginHelperService.addPlugin(
                  authModel,
                  function success(res) {
                    return resolve(oauthClient);
                  }, function (err) {
                    return reject(err);
                  })
              });
            })
            .then(function (oauthClient) {
              var pepModel = {
                name: 'gluu-uma-pep',
                config: {
                  oxd_id: oauthClient.oxd_id,
                  client_id: oauthClient.client_id,
                  client_secret: oauthClient.client_secret,
                  op_url: model.config.op_url,
                  oxd_url: model.config.oxd_url,
                  uma_scope_expression: model.config.uma_scope_expression,
                  deny_by_default: model.config.deny_by_default || false
                }
              };
              if ($scope.context_name) {
                pepModel[$scope.context_name] ={
                  id: $scope.context_data.id
                }
              }
              return PluginHelperService.addPlugin(
                pepModel,
                function success(res) {
                  $state.go(($scope.context_name || "plugin") + "s");
                  MessageService.success('Gluu UMA Auth and PEP Plugin added successfully!');
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

        function updatePlugin() {
          var model = angular.copy($scope.modelPlugin);
          var uma_scope_expression = makeExpression($scope.modelPlugin);

          if (uma_scope_expression && uma_scope_expression.length > 0) {
            model.config.uma_scope_expression = JSON.stringify(uma_scope_expression);
          } else {
            model.config.uma_scope_expression = null;
          }

          if (model.isPEPEnabled && !model.config.uma_scope_expression) {
            MessageService.error("UMA scope expression is required");
            return;
          }

          PluginsService
            .updateResources({
              oxd_id: model.config.oxd_id || null,
              client_id: model.config.client_id || null,
              client_secret: model.config.client_secret || null,
              uma_scope_expression: uma_scope_expression,
              op_host: model.config.op_url,
              oxd_url: model.config.oxd_url
            })
            .then(function (response) {
              if (!response.data.oxd_id) {
                console.log(response);
                return MessageService.error("Failed to update UMA resources");
              }
              var authModel = {
                name: 'gluu-uma-auth',
                config: {
                  oxd_id: model.oxd_id,
                  client_id: model.client_id,
                  client_secret: model.client_secret,
                  op_url: model.config.op_url,
                  oxd_url: model.config.oxd_url,
                  anonymous: model.config.anonymous,
                  pass_credentials: model.config.pass_credentials
                }
              };
              if ($scope.context_name) {
                authModel[$scope.context_name] = {
                  id: $scope.context_data.id
                };
              }

              if (model.tags) {
                authModel.tags = model.tags
              }

              return new Promise(function (resolve, reject) {
                return PluginHelperService.updatePlugin(model.authId,
                  authModel,
                  function success(res) {
                    return resolve();
                  }, function (err) {
                    return reject(err);
                  });
              });
            })
            .then(function () {
              var pepModel = {
                name: 'gluu-uma-pep',
                config: {
                  oxd_id: model.oxd_id,
                  client_id: model.client_id,
                  client_secret: model.client_secret,
                  op_url: model.config.op_url,
                  oxd_url: model.config.oxd_url,
                  uma_scope_expression: model.config.uma_scope_expression,
                  deny_by_default: model.config.deny_by_default || false
                }
              };
              if ($scope.context_name) {
                pepModel[$scope.context_name] = {
                  id: $scope.context_data.id
                };
              }
              return PluginHelperService.updatePlugin(model.pepId,
                pepModel,
                function success(res) {
                  $state.go(($scope.context_name || "plugin") + "s");
                  MessageService.success('Gluu UMA Auth and PEP Plugin added successfully!');
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

        function loadMethods(query) {
          var arr = ['GET', 'POST', 'DELETE', 'PUT', 'PATCH', 'OPTIONS', 'CONNECT', 'TRACE', 'HEAD', '?'];
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
            model.config.uma_scope_expression.forEach(function (path, pIndex) {
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
            return model.config.uma_scope_expression;
          } catch (e) {
            MessageService.error("Invalid UMA scope expression");
            return null;
          }
        }

        function checkDuplicateMethod() {
          var model = angular.copy($scope.modelPlugin);
          var methodFlag = false;

          model.config.uma_scope_expression.forEach(function (path, pIndex) {
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
          var model = angular.copy($scope.modelPlugin);
          var pathFlag = false;
          var paths = [];
          model.config.uma_scope_expression.forEach(function (path, pIndex) {
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
            $scope.modelPlugin.config.anonymous = consumer.id;
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

        //init
        $scope.fetchData();
      }
    ]);
}());
