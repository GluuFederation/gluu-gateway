(function () {
  'use strict';

  angular.module('frontend.apis')
    .controller('ManageUmaRsPluginController', [
      '_', '$scope', '$log', '$state', 'ApiService', 'PluginsService', 'MessageService',
      '$uibModal', 'DialogService', 'PluginModel', 'ListConfig', 'UserService', 'ApiModel', 'PluginHelperService', '_api', '_plugins', '$compile', 'InfoService', '$localStorage',
      function controller(_, $scope, $log, $state, ApiService, PluginsService, MessageService,
                          $uibModal, DialogService, PluginModel, ListConfig, UserService, ApiModel, PluginHelperService, _api, _plugins, $compile, InfoService, $localStorage) {
        $scope.globalInfo = $localStorage.credentials.user;
        $scope.api = _api.data
        $scope.plugins = _plugins.data.data
        $scope.rsPlugin = null;
        $scope.addNewCondition = addNewCondition
        $scope.addNewPath = addNewPath
        $scope.showResourceJSON = showResourceJSON
        $scope.managePlugin = managePlugin
        $scope.loadMethods = loadMethods
        $scope.loadScopes = loadScopes
        $scope.addGroup = addGroup
        $scope.removeGroup = removeGroup
        $scope.fetchData = fetchData
        $scope.setActiveCategory = setActiveCategory
        $scope.addOauthNewPath = addOauthNewPath
        $scope.addOauthNewCondition = addOauthNewCondition
        $scope.addOauthGroup = addOauthGroup
        $scope.removeOauthGroup = removeOauthGroup
        $scope.showOauthResourceJSON = showOauthResourceJSON

        $scope.categories = [{id: 'uma', title: 'UMA Resources'}, {id: 'oauth', title: 'OAuth Scope Security'}]
        $scope.activeCategory = 'uma';

        $scope.modelPlugin = {
          api_id: $scope.api.id,
          name: 'gluu-oauth2-rs',
          config: {
            oxd_host: $scope.globalInfo.oxdWeb,
            uma_server_host: $scope.globalInfo.opHost,
            protection_document: [{
              path: '',
              conditions: [
                {
                  httpMethods: [{text: 'GET'}, {text: 'POST'}],
                  scope_expression: [],
                  ticketScopes: []
                }]
            }],
            oauth_scope_expression: []
          }
        };

        $scope.isKongUMARSPluginAdded = false;

        $scope.plugins.forEach(function (o) {
          if (o.name == "gluu-oauth2-rs") {
            $scope.pluginConfig = o.config;
            $scope.rsPlugin = o;
            $scope.isKongUMARSPluginAdded = true;
            $scope.ruleScope = {};
            $scope.ruleOauthScope = {};
            $scope.modelPlugin.config.protection_document = JSON.parse(o.config.protection_document || "[]");
            $scope.modelPlugin.config.oauth_scope_expression = JSON.parse(o.config.oauth_scope_expression || "[]");
            setTimeout(function () {
              if ($scope.modelPlugin.config.protection_document && $scope.modelPlugin.config.protection_document.length > 0) {
                $scope.modelPlugin.config.protection_document.forEach(function (path, pIndex) {
                  path.conditions.forEach(function (cond, cIndex) {
                    var pRule = cond.scope_expression.rule;
                    var op = '';
                    if (pRule['and']) {
                      op = 'and'
                    } else if (pRule['or']) {
                      op = 'or'
                    } else if (pRule['not']) {
                      op = 'not'
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
                            "<input type=\"radio\" value=\"not\" name=\"condition" + pIndex + cIndex + id + "\" " + (op == "not" ? "checked" : "") + ">not " +
                            "<button type=\"button\" class=\"btn btn-xs btn-success\" data-add=\"rule\" data-ng-click=\"addGroup('" + pIndex + cIndex + "', " + (id + 1) + ")\"><i class=\"mdi mdi-plus\"></i> Add Group</button> " +
                            removeBtn +
                            "<div class=\"form-group has-feedback\"> " +
                            "<input type=\"hidden\" value=\"{{ruleScope['scope" + pIndex + cIndex + id + "']}}\" name=\"hdScope" + pIndex + cIndex + id + "\" /> " +
                            "<tags-input ng-model=\"ruleScope['scope" + pIndex + cIndex + id + "']\" required name=\"scope" + pIndex + cIndex + id + "\" id=\"scope" + pIndex + cIndex + id + "\" placeholder=\"Enter scopes\"></tags-input> " +
                            "</div>" +
                            "<div class=\"col-md-12\" id=\"dyScope" + pIndex + cIndex + (id + 1) + "\"></div>";

                          $("#dyScope" + pIndex + cIndex + id).append(htmlRender);
                          $compile(angular.element("#dyScope" + pIndex + cIndex + id).contents())($scope)
                          // end
                        }

                        if (oRule['and']) {
                          _repeat(oRule['and'], 'and', ++id);
                        } else if (oRule['or']) {
                          _repeat(oRule['or'], 'or', ++id);
                        } else if (oRule['not']) {
                          _repeat(oRule['not'], 'not', ++id);
                        }
                      });
                    }
                  });
                });
              }
              if ($scope.modelPlugin.config.oauth_scope_expression && $scope.modelPlugin.config.oauth_scope_expression.length > 0) {
                $scope.modelPlugin.config.oauth_scope_expression.forEach(function (path, pIndex) {
                  path.conditions.forEach(function (cond, cIndex) {
                    var pRule = cond.scope_expression;
                    var op = '';
                    if (pRule['and']) {
                      op = 'and'
                    } else if (pRule['or']) {
                      op = 'or'
                    } else if (pRule['not']) {
                      op = 'not'
                    }

                    _repeatOAuth(pRule[op], op, 0);

                    function _repeatOAuth(rule, op, id) {
                      $("input[name=hdOauthScopeCount" + pIndex + cIndex + "]").val(id + 1);
                      rule.forEach(function (oRule, oRuleIndex) {
                        if (!$scope.ruleOauthScope["scope" + pIndex + cIndex + id]) {
                          $scope.ruleOauthScope["scope" + pIndex + cIndex + id] = [];
                        }
                        if (typeof oRule === "string") {
                          $scope.ruleOauthScope["scope" + pIndex + cIndex + id].push({text: oRule});
                        }


                        if (rule.length - 1 == oRuleIndex) {
                          // show delete button
                          var removeBtn = "<button type=\"button\" class=\"btn btn-xs btn-danger\" data-add=\"rule\" data-ng-click=\"removeOauthGroup('" + pIndex + cIndex + "', " + id + ")\"><i class=\"mdi mdi-close\"></i> Delete</button> ";
                          if (id == 0) {
                            removeBtn = ""
                          }
                          // render template
                          var htmlRender = "<input type=\"radio\" value=\"or\" name=\"oauthCondition" + pIndex + cIndex + id + "\" " + (op == "or" ? "checked" : "") + ">or | " +
                            "<input type=\"radio\" value=\"and\" name=\"oauthCondition" + pIndex + cIndex + id + "\" " + (op == "and" ? "checked" : "") + ">and | " +
                            "<input type=\"radio\" value=\"not\" name=\"oauthCondition" + pIndex + cIndex + id + "\" " + (op == "not" ? "checked" : "") + ">not " +
                            "<button type=\"button\" class=\"btn btn-xs btn-success\" data-add=\"rule\" data-ng-click=\"addOauthGroup('" + pIndex + cIndex + "', " + (id + 1) + ")\"><i class=\"mdi mdi-plus\"></i> Add Group</button> " +
                            removeBtn +
                            "<div class=\"form-group has-feedback\"> " +
                            "<input type=\"hidden\" value=\"{{ruleOauthScope['scope" + pIndex + cIndex + id + "']}}\" name=\"hdOauthScope" + pIndex + cIndex + id + "\" /> " +
                            "<tags-input ng-model=\"ruleOauthScope['scope" + pIndex + cIndex + id + "']\" required name=\"oauthScope" + pIndex + cIndex + id + "\" id=\"oauthScope" + pIndex + cIndex + id + "\" placeholder=\"Enter oauth scopes\"></tags-input> " +
                            "</div>" +
                            "<div class=\"col-md-12\" id=\"dyOauthScope" + pIndex + cIndex + (id + 1) + "\"></div>";

                          $("#dyOauthScope" + pIndex + cIndex + id).append(htmlRender);
                          $compile(angular.element("#dyOauthScope" + pIndex + cIndex + id).contents())($scope)
                          // end
                        }

                        if (oRule['and']) {
                          _repeatOAuth(oRule['and'], 'and', ++id);
                        } else if (oRule['or']) {
                          _repeatOAuth(oRule['or'], 'or', ++id);
                        } else if (oRule['not']) {
                          _repeatOAuth(oRule['not'], 'not', ++id);
                        }
                      });
                    }
                  });
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
              $scope.info = resp.data
              $log.debug("DashboardController:fetchData:info", $scope.info)
            })
        }

        function removeGroup(parent, id) {
          $("#dyScope" + parent + id).html('');
          $("input[name=hdScopeCount" + parent + "]").val(id);
        }

        function addGroup(parent, id) {
          $("input[name=hdScopeCount" + parent + "]").val(id + 1);
          var htmlRender = "<div class=\"col-md-12\">" +
            "<input type=\"radio\" value=\"or\" name=\"condition" + parent + id + "\" checked>or | <input type=\"radio\" value=\"and\" name=\"condition" + parent + id + "\">and | <input type=\"radio\" value=\"not\" name=\"condition" + parent + id + "\">not" +
            "<button type=\"button\" class=\"btn btn-xs btn-success\" data-add=\"rule\" data-ng-click=\"addGroup('" + parent + "', " + (id + 1) + ")\"><i class=\"mdi mdi-plus\"></i> Add Group</button> " +
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
          $scope.modelPlugin.config.protection_document[pIndex].conditions.push(
            {
              httpMethods: [{text: 'GET'}],
              scope_expression: [],
              ticketScopes: []
            });

          if ($scope.isKongUMARSPluginAdded) {
            var parent = pIndex + '' + ($scope.modelPlugin.config.protection_document[pIndex].conditions.length - 1);
            var id = 0;
            setTimeout(function () {
              var htmlRender = "<input type=\"radio\" value=\"or\" name=\"condition" + parent + "0\" checked>or | <input type=\"radio\" value=\"and\" name=\"condition" + parent + "0\">and | <input type=\"radio\" value=\"not\" name=\"condition" + parent + "0\">not " +
                "<button type=\"button\" class=\"btn btn-xs btn-success\" data-add=\"rule\" data-ng-click=\"addGroup('" + parent + "',1)\"><i class=\"mdi mdi-plus\"></i> Add Group </button>" +
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
          model.config.protection_document = makeJSON(model);
          if (model.config.protection_document == null) {
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
          $scope.modelPlugin.config.protection_document.push({
            path: '',
            conditions: [
              {
                httpMethods: [{text: 'GET'}],
                scope_expression: [],
                ticketScopes: []
              }
            ]
          });

          if ($scope.isKongUMARSPluginAdded) {
            var parent = $scope.modelPlugin.config.protection_document.length - 1 + '0';
            var id = 0;
            setTimeout(function () {
              var htmlRender = "<input type=\"radio\" value=\"or\" name=\"condition" + parent + "0\" checked>or | <input type=\"radio\" value=\"and\" name=\"condition" + parent + "0\">and | <input type=\"radio\" value=\"not\" name=\"condition" + parent + "0\">not" +
                "<button type=\"button\" class=\"btn btn-xs btn-success\" data-add=\"rule\" data-ng-click=\"addGroup('" + parent + "',1)\"><i class=\"mdi mdi-plus\"></i> Add Group </button>" +
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

        function managePlugin(isValid) {
          if (!isValid) {
            MessageService.error("Please fill all the fields marked in red");
            return false;
          }

          if (checkDuplicatePath()) {
            MessageService.error("UMA Resources: PATH must be unique (but occurs more than one once).");
            return false;
          }

          if (checkDuplicateMethod()) {
            MessageService.error("UMA Resources: HTTP method must be unique within the given PATH (but occurs more than one once).");
            return false;
          }

          if (checkOauthDuplicatePath()) {
            MessageService.error("OAuth Scope Security: PATH must be unique (but occurs more than one once).");
            return false;
          }

          if (checkOauthDuplicateMethod()) {
            MessageService.error("OAuth Scope Security: HTTP method must be unique within the given PATH (but occurs more than one once).");
            return false;
          }

          if ($scope.isKongUMARSPluginAdded) {
            updatePlugin(isValid);
          } else {
            addPlugin(isValid);
          }
        }

        function addPlugin(isValid) {
          if (!isValid) {
            MessageService.error("Please fill all the fields marked in red");
            return false;
          }
          var model = angular.copy($scope.modelPlugin);

          if (!model) {
            return false;
          }

          var protectedDocument = makeJSON($scope.modelPlugin)
          if (protectedDocument && protectedDocument.length > 0) {
            model.config.protection_document = JSON.stringify(protectedDocument);
            if (model.config.protection_document == "null") {
              return
            }
          } else {
            delete model.config.protection_document
          }

          var oauthScopeExpression = makeOAuthScopeJSON($scope.modelPlugin)
          if (oauthScopeExpression && oauthScopeExpression.length > 0) {
            model.config.oauth_scope_expression = JSON.stringify(oauthScopeExpression);
            if (model.config.oauth_scope_expression == "null") {
              return
            }
          } else {
            delete model.config.oauth_scope_expression
          }
          if (!model.config.oauth_scope_expression && !model.config.protection_document) {
            MessageService.error("Invalid request. Configured at least one security.");
            return
          }

          PluginHelperService.addPlugin(
            model,
            function success(res) {
              console.log("create plugin", res)
              $scope.busy = false;
              MessageService.success('Plugin added successfully!')
              $state.go('apis') // return to plugins page if specified
            }, function (err) {
              $scope.busy = false;
              $log.error("create plugin", err)
              var errors = {}

              if (err.status && err.status == 400) {
                MessageService.error("OXD Error: Please check the oxd server log");
                return;
              }

              if (err.data.customMessage) {
                Object.keys(err.data.customMessage).forEach(function (key) {
                  errors[key.replace('config.', '')] = err.data.customMessage[key];
                  MessageService.error(key + " : " + err.data.customMessage[key]);
                })
              } else if (err.data.body) {
                Object.keys(err.data.body).forEach(function (key) {
                  errors[key] = err.data.body[key];
                  MessageService.error(key + " : " + err.data.body[key]);
                })
              } else {
                MessageService.error("Invalid UMA Resources");
              }

              $scope.errors = errors
            }, function evt(event) {
              // Only used for ssl plugin certs upload
              var progressPercentage = parseInt(100.0 * event.loaded / event.total);
              $log.debug('progress: ' + progressPercentage + '% ' + event.config.data.file.name);
            });
        }

        function updatePlugin(isValid) {
          if (!isValid) {
            MessageService.error("Please fill all the fields marked in red.");
            return false;
          }
          var model = angular.copy($scope.modelPlugin);

          if (!model) {
            return false;
          }

          model.config = angular.copy($scope.rsPlugin.config);
          model.config.protection_document = $scope.modelPlugin.config.protection_document;
          model.config.oauth_scope_expression = $scope.modelPlugin.config.oauth_scope_expression;

          if (model.config.oauth_scope_expression && model.config.oauth_scope_expression.length > 0) {
            model.config.oauth_scope_expression = JSON.stringify(makeOAuthScopeJSON($scope.modelPlugin));
            if (model.config.oauth_scope_expression == "null") {
              return
            }
          } else {
            delete model.config.oauth_scope_expression
          }

          if (model.config.protection_document && model.config.protection_document.length > 0) {
            model.config.protection_document = JSON.stringify(makeJSON($scope.modelPlugin));
            if (model.config.protection_document == "null") {
              return
            }
          } else {
            delete model.config.protection_document
          }

          if (!model.config.oauth_scope_expression && !model.config.protection_document) {
            MessageService.error("Invalid request. Configured at least one security.");
            return
          }

          PluginHelperService.updatePlugin($scope.rsPlugin.id,
            model,
            function success(res) {
              console.log("update plugin", res)
              $scope.busy = false;
              MessageService.success('Plugin updated successfully!')
              $state.go('apis') // return to plugins page if specified
            }, function (err) {
              $scope.busy = false;
              $log.error("update plugin", err)
              var errors = {}

              if (err.status && err.status == 400) {
                MessageService.error("OXD Error: Please check the oxd server log");
                return
              }

              if (err.data.customMessage) {
                Object.keys(err.data.customMessage).forEach(function (key) {
                  errors[key.replace('config.', '')] = err.data.customMessage[key];
                  MessageService.error(key + " : " + err.data.customMessage[key]);
                })
              } else if (err.data.body) {
                Object.keys(err.data.body).forEach(function (key) {
                  errors[key] = err.data.body[key];
                  MessageService.error(key + " : " + err.data.body[key]);
                })
              } else {
                MessageService.error("Invalid UMA Resources");
              }

              $scope.errors = errors
            }, function evt(event) {
              // Only used for ssl plugin certs upload
              var progressPercentage = parseInt(100.0 * event.loaded / event.total);
              $log.debug('progress: ' + progressPercentage + '% ' + event.config.data.file.name);
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

        function makeJSON(data) {
          try {
            var model = angular.copy(data);
            var dIndex = 0;
            var sData = [];
            model.config.protection_document.forEach(function (path, pIndex) {
              path.conditions.forEach(function (cond, cIndex) {
                dIndex = 0;
                sData = [];
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
            });
            return JSON.parse(angular.toJson(model.config.protection_document));
          } catch (e) {
            MessageService.error("Invalid UMA resources");
            return null;
          }
        }

        function checkDuplicateMethod() {
          var model = angular.copy($scope.modelPlugin);
          var methodFlag = false;

          model.config.protection_document.forEach(function (path, pIndex) {
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
          model.config.protection_document.forEach(function (path, pIndex) {
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

        function checkOauthDuplicateMethod() {
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

        function checkOauthDuplicatePath() {
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

        /**
         * ----------------------------------------------------------------------
         * Functions for oauth scope expression
         * ----------------------------------------------------------------------
         */
        function setActiveCategory(o) {
          $scope.activeCategory = o.id
        }

        function addOauthNewPath() {
          $scope.modelPlugin.config.oauth_scope_expression.push({
            path: '',
            conditions: [
              {
                httpMethods: [{text: 'GET'}],
                scope_expression: []
              }
            ]
          });

          if ($scope.isKongUMARSPluginAdded && $scope.modelPlugin.config.oauth_scope_expression && $scope.modelPlugin.config.oauth_scope_expression.length > 0) {
            var parent = $scope.modelPlugin.config.oauth_scope_expression.length - 1 + '0';
            var id = 0;
            setTimeout(function () {
              var htmlRender = "<input type=\"radio\" value=\"or\" name=\"oauthCondition" + parent + "0\" checked>or | <input type=\"radio\" value=\"and\" name=\"oauthCondition" + parent + "0\">and | <input type=\"radio\" value=\"not\" name=\"oauthCondition" + parent + "0\">not" +
                "<button type=\"button\" class=\"btn btn-xs btn-success\" data-add=\"rule\" data-ng-click=\"addOauthGroup('" + parent + "',1)\"><i class=\"mdi mdi-plus\"></i> Add Group </button>" +
                "<input type=\"hidden\" value=\"{{oauthCond['scopes' + " + parent + " + '0']}}\" name=\"hdOauthScope" + parent + "0\"/>" +
                "<div class=\"form-group has-feedback\">" +
                "<tags-input ng-model=\"oauthCond['scopes' + " + parent + " + '0']\" required name=\"oauthScope" + parent + "0\" id=\"oauthScope" + parent + "\" placeholder=\"Enter oauth scopes\"> </tags-input>" +
                "</div>" +
                "<div class=\"col-md-12\" id=\"dyOauthScope" + parent + (id + 1) + "\"></div>" +
                "</div>";
              $("#dyOauthScope" + parent + '' + id).append(htmlRender);
              $compile(angular.element("#dyOauthScope" + parent + id).contents())($scope)
            });
          }
        }

        function addOauthNewCondition(pIndex) {
          $scope.modelPlugin.config.oauth_scope_expression[pIndex].conditions.push(
            {
              httpMethods: [{text: 'GET'}],
              scope_expression: []
            });

          if ($scope.isKongUMARSPluginAdded && $scope.modelPlugin.config.oauth_scope_expression && $scope.modelPlugin.config.oauth_scope_expression.length > 0) {
            var parent = pIndex + '' + ($scope.modelPlugin.config.oauth_scope_expression[pIndex].conditions.length - 1);
            var id = 0;
            setTimeout(function () {
              var htmlRender = "<input type=\"radio\" value=\"or\" name=\"oauthCondition" + parent + "0\" checked>or | <input type=\"radio\" value=\"and\" name=\"oauthCondition" + parent + "0\">and | <input type=\"radio\" value=\"not\" name=\"oauthCondition" + parent + "0\">not " +
                "<button type=\"button\" class=\"btn btn-xs btn-success\" data-add=\"rule\" data-ng-click=\"addOauthGroup('" + parent + "',1)\"><i class=\"mdi mdi-plus\"></i> Add Group </button>" +
                "<input type=\"hidden\" value=\"{{oauthCond['scopes' + " + parent + " + '0']}}\" name=\"hdOauthScope" + parent + "0\"/>" +
                "<div class=\"form-group has-feedback\">" +
                "<tags-input ng-model=\"oauthCond['scopes' + " + parent + " + '0']\" required name=\"oauthScope" + parent + "0\" id=\"oauthScope" + parent + "\" placeholder=\"Enter oauth scopes\"></tags-input>" +
                "</div>" +
                "<div class=\"col-md-12\" id=\"dyOauthScope" + parent + (id + 1) + "\"></div>";

              $("#dyOauthScope" + parent + '' + id).append(htmlRender);
              $compile(angular.element("#dyOauthScope" + parent + id).contents())($scope)
            });
          }
        }

        function addOauthGroup(parent, id) {
          $("input[name=hdOauthScopeCount" + parent + "]").val(id + 1);
          var htmlRender = "<div class=\"col-md-12\">" +
            "<input type=\"radio\" value=\"or\" name=\"oauthCondition" + parent + id + "\" checked>or | <input type=\"radio\" value=\"and\" name=\"oauthCondition" + parent + id + "\">and | <input type=\"radio\" value=\"not\" name=\"oauthCondition" + parent + id + "\">not" +
            "<button type=\"button\" class=\"btn btn-xs btn-success\" data-add=\"rule\" data-ng-click=\"addOauthGroup('" + parent + "', " + (id + 1) + ")\"><i class=\"mdi mdi-plus\"></i> Add Group</button> " +
            "<button type=\"button\" class=\"btn btn-xs btn-danger\" data-add=\"rule\" data-ng-click=\"removeOauthGroup('" + parent + "', " + id + ")\"><i class=\"mdi mdi-close\"></i> Delete</button>" +
            "<input type=\"hidden\" value=\"{{oauthCond['scopes" + parent + id + "']}}\" name=\"hdOauthScope" + parent + id + "\" />" +
            "<div class=\"form-group has-feedback\">" +
            "<tags-input type=\"url\" ng-model=\"oauthCond['scopes" + parent + id + "']\" required name=\"oauthScope" + id + "\" id=\"oauthScope{{$parent.$index}}{{$index}}\" placeholder=\"Enter oauth scopes\"> </tags-input>" +
            "</div>" +
            "<div class=\"col-md-12\" id=\"dyOauthScope" + parent + (id + 1) + "\"></div>" +
            "</div>";
          $("#dyOauthScope" + parent + id).append(htmlRender);
          $compile(angular.element("#dyOauthScope" + parent + id).contents())($scope)
        }

        function removeOauthGroup(parent, id) {
          $("#dyOauthScope" + parent + id).html('');
          $("input[name=hdOauthScopeCount" + parent + "]").val(id);
        }

        function makeOAuthScopeJSON(data) {
          try {
            var model = angular.copy(data);
            var dIndex = 0;
            model.config.oauth_scope_expression.forEach(function (path, pIndex) {
              path.conditions.forEach(function (cond, cIndex) {
                dIndex = 0;
                var str = '{%s}';
                for (var i = 0; i < parseInt($("input[name=hdOauthScopeCount" + pIndex + cIndex + "]").val()); i++) {
                  var op = $("input[name=oauthCondition" + pIndex + cIndex + i + "]:checked").val();
                  var s = "";
                  JSON.parse($("input[name=hdOauthScope" + pIndex + cIndex + i + "]").val()).forEach(function (o) {
                    s += "\"" + o.text + "\"" + ","
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
                cond.scope_expression = JSON.parse(str);
              });
            });
            return JSON.parse(angular.toJson(model.config.oauth_scope_expression));
          } catch (e) {
            MessageService.error("Invalid OAuth scope expression");
            return null;
          }
        }

        function showOauthResourceJSON() {
          var model = angular.copy($scope.modelPlugin);
          model.config.oauth_scope_expression = makeOAuthScopeJSON(model);
          if (model.config.oauth_scope_expression == null) {
            return
          }

          if (!model) {
            return false;
          }

          $uibModal.open({
            animation: true,
            templateUrl: 'js/app/plugins/modals/show-oauth-scope-json-modal.html',
            size: 'lg',
            controller: ['$uibModalInstance', '$scope', 'modelPlugin', ShowOAuthScopeController],
            resolve: {
              modelPlugin: function () {
                return model;
              }
            }
          }).result.then(function (result) {
          });
        }

        function ShowOAuthScopeController($uibModalInstance, $scope, modelPlugin) {
          $scope.model = angular.copy(modelPlugin);
        }

        //init
        $scope.fetchData()
      }
    ])
  ;
}());
