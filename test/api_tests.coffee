Meteor.startup ->

  describe 'An API', ->
    context 'that hasn\'t been configured', ->
      it 'should have default settings', (test) ->
        test.equal Restivus.config.apiPath, 'api/'
        test.isFalse Restivus.config.useAuth
        test.isFalse Restivus.config.prettyJson
        test.equal Restivus.config.auth.token, 'services.resume.loginTokens.token'

      it 'should allow you to add an unconfigured route', (test) ->
        Restivus.addRoute 'test1', {authRequired: true, roleRequired: 'admin'},
          get: ->
            1
        # TODO: Access routes in a less brittle way than this index that can change when new routes are added (more below)
        route = Restivus.routes[2]
        test.equal route.path, 'test1'
        test.equal route.endpoints.get(), 1
        test.isTrue route.options.authRequired
        test.equal route.options.roleRequired, 'admin'
        test.isUndefined route.endpoints.get.authRequired
        test.isUndefined route.endpoints.get.roleRequired

      it 'should allow you to add an unconfigured collection route', (test) ->
        Restivus.addCollection new Mongo.Collection('tests'),
          routeOptions:
            authRequired: true
            roleRequired: 'admin'
          endpoints:
            getAll:
              action: ->
                2

        route = Restivus.routes[3]
        test.equal route.path, 'tests'
        test.equal route.endpoints.get.action(), 2
        test.isTrue route.options.authRequired
        test.equal route.options.roleRequired, 'admin'
        test.isUndefined route.endpoints.get.authRequired
        test.isUndefined route.endpoints.get.roleRequired

      it 'should be configurable', (test) ->
        Restivus.configure
          apiPath: 'api/v1'
          useAuth: true
          auth: token: 'apiKey'
          defaultHeaders:
            'Content-Type': 'text/json'
            'X-Test-Header': 'test header'

        config = Restivus.config
        test.equal config.apiPath, 'api/v1/'
        test.equal config.useAuth, true
        test.equal config.auth.token, 'apiKey'
        test.equal config.defaultHeaders['Content-Type'], 'text/json'
        test.equal config.defaultHeaders['X-Test-Header'], 'test header'
        test.equal config.defaultHeaders['Access-Control-Allow-Origin'], '*'

    context 'that has been configured', ->
      it 'should not allow reconfiguration', (test) ->
        test.throws Restivus.configure, 'Restivus.configure() can only be called once'

      it 'should configure any previously added routes', (test) ->
        route = Restivus.routes[2]
        test.equal route.endpoints.get.action(), 1
        test.isTrue route.endpoints.get.authRequired
        test.equal route.endpoints.get.roleRequired, ['admin']

      it 'should configure any previously added collection routes', (test) ->
        route = Restivus.routes[3]
        test.equal route.endpoints.get.action(), 2
        test.isTrue route.endpoints.get.authRequired
        test.equal route.endpoints.get.roleRequired, ['admin']


  describe 'A collection route', ->
    it 'should be able to exclude endpoints using just the excludedEndpoints option', (test, next) ->
      Restivus.addCollection new Mongo.Collection('tests2'),
        excludedEndpoints: ['get', 'getAll']


      HTTP.get 'http://localhost:3000/api/v1/tests2/10', (error, result) ->
        response = JSON.parse result.content
        test.isTrue error
        test.equal result.statusCode, 404
        test.equal response.status, 'error'
        test.equal response.message, 'API endpoint not found'

      HTTP.get 'http://localhost:3000/api/v1/tests2/', (error, result) ->
        response = JSON.parse result.content
        test.isTrue error
        test.equal result.statusCode, 404
        test.equal response.status, 'error'
        test.equal response.message, 'API endpoint not found'
        next()

    context 'with the default autogenerated endpoints', ->
      Restivus.addCollection new Mongo.Collection('testautogen')
      testId = null

      it 'should support a POST on api/collection', (test) ->
        result = HTTP.post 'http://localhost:3000/api/v1/testAutogen',
          data:
            name: 'test name'
            description: 'test description'
        response = JSON.parse result.content
        responseData = response.data
        test.equal result.statusCode, 201
        test.equal response.status, 'success'
        test.equal responseData.name, 'test name'
        test.equal responseData.description, 'test description'

        # Persist the new resource id
        testId = responseData._id

      it 'should support a PUT on api/collection/:id', (test) ->
        result = HTTP.put "http://localhost:3000/api/v1/testAutogen/#{testId}",
          data:
            name: 'update name'
            description: 'update description'
        response = JSON.parse result.content
        responseData = response.data
        test.equal result.statusCode, 200
        test.equal response.status, 'success'
        test.equal responseData.name, 'update name'
        test.equal responseData.description, 'update description'

        result = HTTP.put "http://localhost:3000/api/v1/testAutogen/#{testId}",
          data:
            name: 'update name with no description'
        response = JSON.parse result.content
        responseData = response.data
        test.equal result.statusCode, 200
        test.equal response.status, 'success'
        test.equal responseData.name, 'update name with no description'
        test.isUndefined responseData.description


  describe 'An endpoint', ->

    it 'should respond with the default headers when not overridden', (test) ->
      Restivus.addRoute 'testDefaultHeaders',
        get: ->
          true

      result = HTTP.get 'http://localhost:3000/api/v1/testDefaultHeaders'

      test.equal result.statusCode, 200
      test.equal result.headers['content-type'], 'text/json'
      test.equal result.headers['x-test-header'], 'test header'
      test.equal result.headers['access-control-allow-origin'], '*'
      test.isTrue result.content

    it 'should allow default headers to be overridden', (test) ->
      Restivus.addRoute 'testOverrideDefaultHeaders',
        get: ->
          headers:
            'Content-Type': 'application/json'
            'Access-Control-Allow-Origin': 'https://mywebsite.com'
          body:
            true

      result = HTTP.get 'http://localhost:3000/api/v1/testOverrideDefaultHeaders'

      test.equal result.statusCode, 200
      test.equal result.headers['content-type'], 'application/json'
      test.equal result.headers['access-control-allow-origin'], 'https://mywebsite.com'
      test.isTrue result.content

    it 'should cause an error when it returns null', (test, next) ->
      Restivus.addRoute 'testNullResponse',
        get: ->
          null

      HTTP.get 'http://localhost:3000/api/v1/testNullResponse', (error, result) ->
        test.isTrue error
        test.equal result.statusCode, 500
        next()

    it 'should cause an error when it returns undefined', (test, next) ->
      Restivus.addRoute 'testUndefinedResponse',
        get: ->
          undefined

      HTTP.get 'http://localhost:3000/api/v1/testUndefinedResponse', (error, result) ->
        test.isTrue error
        test.equal result.statusCode, 500
        next()

    it 'should be able to handle it\'s response manually', (test, next) ->
      Restivus.addRoute 'testManualResponse',
        get: ->
          @response.write 'Testing manual response.'
          @response.end()
          @done()

      HTTP.get 'http://localhost:3000/api/v1/testManualResponse', (error, result) ->
        response = result.content

        test.equal result.statusCode, 200
        test.equal response, 'Testing manual response.'
        next()

    it 'should not have to call this.response.end() when handling the response manually', (test, next) ->
      Restivus.addRoute 'testManualResponseNoEnd',
        get: ->
          @response.write 'Testing this.end()'
          @done()

      HTTP.get 'http://localhost:3000/api/v1/testManualResponseNoEnd', (error, result) ->
        response = result.content

        test.isFalse error
        test.equal result.statusCode, 200
        test.equal response, 'Testing this.end()'
        next()

    it 'should be able to send it\'s response in chunks', (test, next) ->
      Restivus.addRoute 'testChunkedResponse',
        get: ->
          @response.write 'Testing '
          @response.write 'chunked response.'
          @done()

      HTTP.get 'http://localhost:3000/api/v1/testChunkedResponse', (error, result) ->
        response = result.content

        test.equal result.statusCode, 200
        test.equal response, 'Testing chunked response.'
        next()

    it 'should respond with an error if this.done() isn\'t called after response is handled manually', (test, next) ->
      Restivus.addRoute 'testManualResponseWithoutDone',
        get: ->
          @response.write 'Testing'

      HTTP.get 'http://localhost:3000/api/v1/testManualResponseWithoutDone', (error, result) ->
        test.isTrue error
        test.equal result.statusCode, 500
        next()

    it 'should not wrap text with quotes when response Content-Type is text/plain', (test, next) ->
      Restivus.addRoute 'testPlainTextResponse',
        get: ->
          headers:
            'Content-Type': 'text/plain'
          body: 'foo"bar'

      HTTP.get 'http://localhost:3000/api/v1/testPlainTextResponse', (error, result) ->
        response = result.content
        test.equal result.statusCode, 200
        test.equal response, 'foo"bar'
        next()

    it 'should have its context set', (test) ->
      Restivus.addRoute 'testContext/:test',
        post: ->
          test.equal @urlParams.test, '100'
          test.equal @queryParams.test, "query"
          test.equal @bodyParams.test, "body"
          test.isNotNull @request
          test.isNotNull @response
          test.isTrue _.isFunction @done
          test.isFalse @authRequired
          test.isFalse @roleRequired
          true

      result = HTTP.post 'http://localhost:3000/api/v1/testContext/100?test=query',
        data:
          test: 'body'

      test.equal result.statusCode, 200
      test.isTrue result.content


#      context 'that has been authenticated', ->
#        it 'should have access to this.user and this.userId', (test) ->
