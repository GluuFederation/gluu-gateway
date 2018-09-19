(function () {
  'use strict';

  angular.module('frontend.plugins')
    .controller('OAuthPluginController', [
      '_', '$scope', '$log', '$state', 'ApiService', 'PluginsService', 'MessageService',
      '$uibModal', 'DialogService', 'PluginModel', 'ListConfig', 'UserService', 'ApiModel', 'PluginHelperService', '_context_name', '_context_data', '_plugins', '$compile', 'InfoService', '$localStorage',
      function controller(_, $scope, $log, $state, ApiService, PluginsService, MessageService,
                          $uibModal, DialogService, PluginModel, ListConfig, UserService, ApiModel, PluginHelperService, _context_name, _context_data, _plugins, $compile, InfoService, $localStorage) {
        $scope.globalInfo = $localStorage.credentials.user;
        $scope.context_data = (_context_data && _context_data.data) || null;
        $scope.context_name = _context_name || null;
        $scope.context_upstream = '';
        $scope.plugins = _plugins.data.data;
        $scope.oauthPlugin = null;
        $scope.addNewCondition = addNewCondition;
        $scope.addNewPath = addNewPath;
        $scope.showResourceJSON = showResourceJSON;
        $scope.managePlugin = managePlugin;
        $scope.loadMethods = loadMethods;
        $scope.loadScopes = loadScopes;
        $scope.addGroup = addGroup;
        $scope.removeGroup = removeGroup;
        $scope.fetchData = fetchData;

        if (_context_name == 'service') {
          $scope.context_upstream = $scope.context_data.protocol + "://" + $scope.context_data.host;
        } else if (_context_name == 'route') {
          $scope.context_upstream = $scope.context_data.protocols[0] + "://" + (($scope.context_data.hosts && $scope.context_data.hosts[0]) || ($scope.context_data.paths && $scope.context_data.paths[0]) || ($scope.context_data['methods'] && $scope.context_data['methods'][0]));
        } else if (_context_name == 'api') {
          $scope.context_upstream = $scope.context_data.upstream_url;
        }

        $scope.modelPlugin = {
          name: 'gluu-oauth2-client-auth',
          config: {
            oxd_url: $scope.globalInfo.oxdWeb,
            op_url: $scope.globalInfo.opHost,
            oxd_id: $scope.globalInfo.oxdId,
            client_id: $scope.globalInfo.clientId,
            client_secret: $scope.globalInfo.clientSecret,
            oauth_scope_expression: [],
            allow_oauth_scope_expression: false,
            hide_credentials: false
          }
        };

        if ($scope.context_name) {
          $scope.modelPlugin[$scope.context_name + "_id"] = $scope.context_data.id;
        }

        $scope.isPluginAdded = false;

        $scope.plugins.forEach(function (o) {
          if (o.name == "gluu-oauth2-client-auth") {
            $scope.modelPlugin = o;
            $scope.isPluginAdded = true;
            $scope.ruleScope = {};
            $scope.ruleOauthScope = {};
            $scope.modelPlugin.config.oauth_scope_expression = JSON.parse(o.config.oauth_scope_expression || "[]");
            setTimeout(function () {
              if ($scope.modelPlugin.config.oauth_scope_expression && $scope.modelPlugin.config.oauth_scope_expression.length > 0) {
                $scope.modelPlugin.config.oauth_scope_expression.forEach(function (path, pIndex) {
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
                            "<tags-input ng-model=\"ruleScope['scope" + pIndex + cIndex + id + "']\" required name=\"scope" + pIndex + cIndex + id + "\" id=\"scope" + pIndex + cIndex + id + "\" placeholder=\"Enter scopes\"></tags-input> " +
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
        });

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
            "<tags-input type=\"url\" required ng-model=\"cond['scopes" + parent + id + "']\" name=\"scope" + id + "\" id=\"scopes{{$parent.$index}}{{$index}}\" placeholder=\"Enter scopes\"> </tags-input>" +
            "</div>" +
            "<div class=\"col-md-12\" id=\"dyScope" + parent + (id + 1) + "\"></div>" +
            "</div>";
          $("#dyScope" + parent + id).append(htmlRender);
          $compile(angular.element("#dyScope" + parent + id).contents())($scope)
        }

        function addNewCondition(pIndex) {
          $scope.modelPlugin.config.oauth_scope_expression[pIndex].conditions.push(
            {
              httpMethods: [{text: 'GET'}],
              scope_expression: [],
              ticketScopes: []
            });

          if ($scope.isPluginAdded) {
            var parent = pIndex + '' + ($scope.modelPlugin.config.oauth_scope_expression[pIndex].conditions.length - 1);
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
          var model = angular.copy($scope.modelPlugin);
          model.config.oauth_scope_expression = makeExpression(model);
          if (model.config.oauth_scope_expression == null) {
            return
          }
          if (!model) {
            return false;
          }

          $uibModal.open({
            animation: true,
            templateUrl: 'js/app/plugins/modals/show-resource-json-modal.html',
            size: 'lg',
            controller: ['$uibModalInstance', '$scope', 'modelPlugin', ShowScriptController],
            resolve: {
              modelPlugin: function () {
                return model;
              }
            }
          }).result.then(function (result) {
          });
        }

        function ShowScriptController($uibModalInstance, $scope, modelPlugin) {
          $scope.model = angular.copy(modelPlugin);
        }

        function addNewPath() {
          $scope.modelPlugin.config.oauth_scope_expression.push({
            path: '',
            pathIndex: $scope.modelPlugin.config.oauth_scope_expression.length,
            conditions: [
              {
                httpMethods: [{text: 'GET'}],
                scope_expression: [],
                ticketScopes: []
              }
            ]
          });

          if ($scope.isPluginAdded) {
            var parent = $scope.modelPlugin.config.oauth_scope_expression.length - 1 + '0';
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

        function managePlugin(fElement) {
          var isFormValid = true;
          if (fElement && fElement.$error && fElement.$error.required) {
            fElement.$error.required.forEach(function (o) {
              if (document.getElementById(o.$name)) {
                isFormValid = false;
              }
            });
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
          var oauthScopeExpression = makeExpression($scope.modelPlugin);
          if (oauthScopeExpression && oauthScopeExpression.length > 0) {
            model.config.oauth_scope_expression = oauthScopeExpression;
          } else {
            delete model.config.oauth_scope_expression
          }
          PluginsService.addOAuthClient({
            oxd_id: model.config.oxd_id || null,
            client_id: model.config.client_id || null,
            client_secret: model.config.client_secret || null,
            client_name: 'gluu-oauth2-introspect-client'
          })
            .then(function (response) {
              var oauthClient = response.data;
              model.config.oxd_id = oauthClient.oxd_id;
              model.config.client_id = oauthClient.client_id;
              model.config.client_secret = oauthClient.client_secret;

              PluginHelperService.addPlugin(
                model,
                function success(res) {
                  $state.go($scope.context_name + "s");
                  MessageService.success('Plugin added successfully!');
                }, function (err) {
                  $scope.busy = false;
                  $log.error("create plugin", err);
                  if (err.data.body) {
                    Object.keys(err.data.body).forEach(function (key) {
                      MessageService.error(key + " : " + err.data.body[key]);
                    })
                  } else {
                    MessageService.error("Invalid OAuth scope expression");
                  }
                });

            })
            .catch(function (error) {
              console.log(error);
              MessageService.error("Failed to register client");
            });
        }

        function updatePlugin() {
          var model = angular.copy($scope.modelPlugin);
          model.config.oauth_scope_expression = $scope.modelPlugin.config.oauth_scope_expression;

          if (model.config.oauth_scope_expression && model.config.oauth_scope_expression.length > 0) {
            model.config.oauth_scope_expression = makeExpression($scope.modelPlugin);
          } else {
            delete model.config.oauth_scope_expression
          }

          PluginHelperService.updatePlugin(model.id,
            model,
            function success(res) {
              $scope.busy = false;
              MessageService.success('Plugin updated successfully!');
              $state.go($scope.context_name + "s"); // return to plugins page if specified
            }, function (err) {
              $log.error("create plugin", err);
              if (err.data.body) {
                Object.keys(err.data.body).forEach(function (key) {
                  MessageService.error(key + " : " + err.data.body[key]);
                })
              } else {
                MessageService.error("Invalid OAuth scope expression");
              }
            });
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
            model.config.oauth_scope_expression.forEach(function (path, pIndex) {
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
                  str = str.replace('%s', "\"" + op + "\":[" + s + " {%s}]");

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
            return model.config.oauth_scope_expression;
          } catch (e) {
            MessageService.error("Invalid OAuth scope expression");
            return null;
          }
        }

        function checkDuplicateMethod() {
          var model = angular.copy($scope.modelPlugin);
          var methodFlag = false;

          model.config.oauth_scope_expression.forEach(function (path, pIndex) {
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
          model.config.oauth_scope_expression.forEach(function (path, pIndex) {
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

        //init
        $scope.fetchData()
      }
    ]);
}());