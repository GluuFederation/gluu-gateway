/**
 * This file contains all necessary Angular controller definitions for 'frontend.admin.login-history' module.
 *
 * Note that this file should only contain controllers and nothing else.
 */
(function() {
    'use strict';

    angular.module('frontend.plugins')
        .service('PluginHelperService', [
            '_','$log','BackendConfig','Upload','PluginsService',
            function( _,$log,BackendConfig,Upload,PluginsService) {

                function assignExtraProperties(options,fields,prefix) {
                    Object.keys(fields).forEach(function (item) {
                        if(fields[item].schema) {
                            assignExtraProperties(options,fields[item].schema.fields,item)
                        }else{
                            var path = prefix ? prefix + "." + item : item;
                            var value = fields[item].default

                            if (fields[item].type === 'array'
                                && (typeof value === 'object' || typeof value === 'string')
                            ) {
                                value = []
                            }
                            fields[item].value = value
                            fields[item].help = _.get(options,path) ? _.get(options,path).help : ''
                        }
                    })
                }


                function createConfigProperties(fields,prefix,data) {
                    Object.keys(fields).forEach(function (key) {
                        if(fields[key].schema) {
                            createConfigProperties(fields[key].schema.fields,key,data)
                        }else{
                            var path = prefix ? prefix + "." + key : key;
                            if (fields[key].value instanceof Array) {
                                // Transform to comma separated string
                                data['config.' + path] = fields[key].value.join(",")
                            } else {
                                data['config.' + path] = fields[key].value
                            }
                        }
                    })
                }

                var handlers  = {
                    common : function(data,success,error) {

                        PluginsService.add(data)
                            .then(function(resp){
                                success(resp)
                            }).catch(function(err){
                            error(err)
                        })
                    },
                    ssl : function(data, success,error,event) {
                        var files = [];

                        files.push(data['config.cert'])
                        files.push(data['config.key'])

                        Upload.upload({
                            url: 'kong/plugins',
                            arrayKey: '',
                            data: {
                                file: files,
                                'name' : data.name,
                                'config.only_https': data['config.only_https'],
                                'config.accept_http_if_already_terminated': data['config.accept_http_if_already_terminated']
                            }
                        }).then(function (resp) {
                            success(resp)
                        }, function (err) {
                            error(err)
                        }, function (evt) {
                            event(evt)
                        });
                    }
                }

                return {
                    addPlugin : function(data, success,error,event) {

                        if(handlers[data.name]) {
                            return handlers[data.name](data, success,error,event)
                        }else{
                            return handlers['common'](data, success,error,event)
                        }
                    },

                    createConfigProperties : function(fields,prefix) {
                        var output = {}
                        createConfigProperties(fields,prefix,output)
                        return output
                    },

                    assignExtraProperties : function(options,fields,prefix) {
                        return  assignExtraProperties(options,fields,prefix)
                    },

                    /**
                     * Customize data fields for specified plugins if required by Konga's logic
                     * @param pluginName
                     * @param fields
                     */
                    customizeDataFieldsForPlugin : function(pluginName,fields) {

                        switch (pluginName) {
                            case 'ssl':
                                fields.cert.type = 'file'
                                fields.key.type = 'file'
                                break;
                        }
                    },

                    /**
                     * Mutate request data for specified plugins if required by Konga's logic
                     * @param request_data
                     * @param fields
                     */
                    applyMonkeyPatches : function(request_data,fields) {
                        if(request_data.name === 'response-ratelimiting'
                            && fields.limits.custom_fields) {
                            //console.log("fields.limits.custom_fields",fields.limits.custom_fields)
                            Object.keys(fields.limits.custom_fields)
                                .forEach(function(key){
                                    Object.keys(fields.limits.custom_fields[key])
                                        .forEach(function(cf_key){
                                            request_data['config.limits.' + key + '.' + cf_key] = fields.limits.custom_fields[key][cf_key].value

                                        })
                                })
                        }
                    }

                }
            }
        ])
    ;
}());
