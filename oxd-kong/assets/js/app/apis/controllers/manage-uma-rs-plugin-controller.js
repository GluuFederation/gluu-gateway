(function () {
  'use strict';

  angular.module('frontend.apis')
    .controller('ManageUmaRsPluginController', [
      '_', '$scope', '$log', '$state', 'ApiService', 'PluginsService', 'MessageService',
      '$uibModal', 'DialogService', 'PluginModel', 'ListConfig', 'UserService', 'ApiModel', 'PluginHelperService', '_api', '_plugins', '$compile', 'InfoService',
      function controller(_, $scope, $log, $state, ApiService, PluginsService, MessageService,
                          $uibModal, DialogService, PluginModel, ListConfig, UserService, ApiModel, PluginHelperService, _api, _plugins, $compile, InfoService) {
        $scope.api = _api.data
        $scope.plugins = _plugins.data.data
        $scope.addNewCondition = addNewCondition
        $scope.addNewPath = addNewPath
        $scope.showResourceJSON = showResourceJSON
        $scope.addPlugin = addPlugin
        $scope.loadMethods = loadMethods
        $scope.loadScopes = loadScopes
        $scope.addGroup = addGroup
        $scope.removeGroup = removeGroup
        $scope.fetchData = fetchData
        $scope.modelPlugin = {
          api_id: $scope.api.id,
          name: 'kong-uma-rs',
          config: {
            protection_document: [{
              path: '',
              conditions: [
                {
                  httpMethods: [{text: 'GET'}, {text: 'POST'}],
                  scopes: [
                    {text: 'http://example.com/dev/actions'}
                  ],
                  ticketScopes: []
                }]
            }]
          }
        };
        if ($scope.plugins.length > 0) {
          $scope.modelPlugin.config.protection_document = JSON.parse($scope.plugins[0].config.protection_document)
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
          $("#dyScope" + parent + id).append(`
                      <div class="col-md-12">
                        <input type="radio" value="or" name="condition${parent}${id + 1}">or | <input type="radio" value="and" name="condition${parent}${id + 1}">and | <input type="radio" value="not" name="condition${parent}${id + 1}">not
                        <button type="button" class="btn btn-xs btn-success" data-add="rule" data-ng-click="addGroup('${parent}', ${id + 1})"><i class="mdi mdi-plus"></i> Add Group</button>
                        <button type="button" class="btn btn-xs btn-danger" data-add="rule" data-ng-click="removeGroup('${parent}', ${id})"><i class="mdi mdi-close"></i> Delete</button>
                        <input type="hidden" value="{{cond['scopes${parent}${id + 1}']}}" name="hdScope${parent}${id + 1}" />
                        <div class="form-group has-feedback">
                          <tags-input type="url" ng-model="cond['scopes${parent}${id + 1}']" name="scope${id + 1}" data-ng-disabled="plugins.length > 0"
                                      id="scopes{{$parent.$index}}{{$index}}"
                                      placeholder="Enter scopes">
                            <auto-complete source="loadScopes($query)"
                                           min-length="0"
                                           template="my-custom-template"
                                           debounce-delay="0"></auto-complete>
                          </tags-input>
                          <script type="text/ng-template" id="my-custom-template">
                            <div>
                              <span>{{data.name}}</span>
                            </div>
                          </script>
                        </div>
                        <div class="col-md-12" id="dyScope${parent}${id + 1}">
                        </div>
                      </div>`);
          $compile(angular.element("#dyScope" + parent + id).contents())($scope)
        }

        function addNewCondition(pathIndex) {
          $scope.modelPlugin.config.protection_document[pathIndex].conditions.push(
            {
              httpMethods: [{text: 'GET'}],
              scopes: [
                {text: 'http://example.com/view'}
              ],
              ticketScopes: []
            });
        }

        function showResourceJSON() {
          var model = makeJSON($scope.modelPlugin);
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
                scopes: [
                  {text: 'http://example.com/view'}
                ],
                ticketScopes: []
              }
            ]
          });
        }

        function addPlugin(isValid) {
          if (!isValid) {
            MessageService.error("Invalid UMA Resources");
            return false;
          }
          var model = makeJSON($scope.modelPlugin);

          if (!model) {
            return false;
          }

          model.config.protection_document = (JSON.stringify(model.config.protection_document));
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

              if (err.data.customMessage) {
                Object.keys(err.data.customMessage).forEach(function (key) {
                  errors[key.replace('config.', '')] = err.data.customMessage[key]
                  MessageService.error(key + " : " + err.data.customMessage[key])
                })
              }

              if (err.data.body) {
                Object.keys(err.data.body).forEach(function (key) {
                  errors[key] = err.data.body[key]
                  MessageService.error(key + " : " + err.data.body[key])
                })
              }
              MessageService.error("Invalid UMA Resources");
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
            model.config.protection_document.forEach(function (path, pIndex) {
              path.conditions.forEach(function (cond, cIndex) {
                var str = '{%s}'
                for (var i = 1; i <= parseInt($(`input[name=hdScopeCount${pIndex}${cIndex}]`).val()); i++) {
                  var op = $(`input[name=condition${pIndex}${cIndex}${i}]:checked`).val()
                  var scopes = JSON.parse($(`input[name=hdScope${pIndex}${cIndex}${i}]`).val()).map(function (o) {
                    return o.text;
                  });
                  var s = ""
                  scopes.forEach(function (item) {
                    s += "\""+ item + "\"" + ","
                  });
                  str = str.replace('%s', `"${op}":[${s} {%s}]`);

                  if(!!cond[`scopes${pIndex}${cIndex}${i}`]) {
                    delete cond[`scopes${pIndex}${cIndex}${i}`]
                  }
                }

                cond.httpMethods = cond.httpMethods.map(function (o) {
                  return o.text;
                });
                str = str.replace(', {%s}', '')
                cond.scopes = JSON.parse(str);

                if (cond.ticketScopes.length > 0) {
                  cond.ticketScopes = cond.ticketScopes.map(function (o) {
                    return o.text;
                  });
                } else {
                  delete cond.ticketScopes;
                }
              });
            });

            model.config.protection_document = JSON.parse(angular.toJson(model.config.protection_document));
            return model;
          } catch(e) {
            MessageService.error("Invalid UMA resource");
            return null;
          }
        }

        //init
        $scope.fetchData()
      }
    ])
  ;
}());
