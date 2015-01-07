mongoose = require('mongoose')
mongoose.connect('mongodb://localhost:27017/apis_test')

ApiExample = require('../../lib/api_example')

describe 'ApiExample', ->

  apiExample = null

  beforeEach ->
    apiExample = new ApiExample()
    apiExample.requestHeaders = {}

  afterEach (done)->
    mongoose.connection.collections['api_examples'].drop -> done()

  describe '#populateFromRequest', ->
    it 'assigns the host from the request headers', ->
      request =
        url: '/users'
        method: 'PUT'
        headers:
          host: 'api_though.io'
          "x-spy-rest-desc": 'shows a list of users'
          "x-spy-rest-version": 'v1'
          "x-spy-rest-resource": 'user'

      apiExample.populateFromRequest(request)

      expect(apiExample.host).toEqual('api_though.io')
      expect(apiExample.url).toEqual('/users')
      expect(apiExample.http_method).toEqual('PUT')

      expect(apiExample.description).toEqual('shows a list of users')
      expect(apiExample.version).toEqual('v1')
      expect(apiExample.resource).toEqual('user')

      expect(apiExample.requestHeaders).toEqual(request.headers)

  describe '#guessedVersion', ->

    describe "guessed from URL", ->

      it 'guesses /v2/x to version v2', ->
        apiExample.populateFromRequest
          url: '/v2/x'
          headers: {}

        expect(apiExample.version).toEqual("v2")

      it 'guesses /v2.1/x to version v2.1', ->
        apiExample.populateFromRequest
          url: '/v2.1/x'
          headers: {}

        expect(apiExample.version).toEqual("v2.1")

      it 'guesses /v2 to version v2', ->
        apiExample.populateFromRequest
          url: '/v2'
          headers: {}

        expect(apiExample.version).toEqual("v2")

      it 'guesses /v2.1-pre/users to version v2.1-pre',->
        apiExample.url = '/v2.1-pre'
        apiExample.populateFromRequest
          url: '/v2.1-pre/users'
          headers: {}

        expect(apiExample.version).toEqual("v2.1-pre")

    describe 'guessed from Accept header', ->
      beforeEach ->
        apiExample.url = "/users"

      it 'guesses v3 from application/vnd.github.v3+json', ->
        apiExample.populateFromRequest
          url: '/users'
          headers:
            'accept': 'application/vnd.github.v3+json'

        expect(apiExample.version).toEqual("v3")

      it 'guesses v3.1 from application/vnd.github.v3.1+json', ->
        apiExample.populateFromRequest
          url: '/users'
          headers:
            'accept': 'application/vnd.github.v3.1+json'

        expect(apiExample.version).toEqual("v3.1")

      it 'guesses v3.1 from application/vnd.github.v3.1-pre+json', ->
        apiExample.populateFromRequest
          url: '/users'
          headers:
            'accept': 'application/vnd.github.v3.1+json'

        expect(apiExample.version).toEqual("v3.1")

      it 'guesses v3 from "accept" : "application/vnd.github.v3+json" header', ->
        apiExample.populateFromRequest
          url: 'https://api.github.com/search/repositories?q=tetris+language:assembly&sort=stars&order=desc'
          headers:
            accept: "application/vnd.github.v3+json"

        expect(apiExample.version).toEqual("v3")

      it 'guesses v3 from "Accept: application/vnd.github.v3.text-match+json" header', ->
        apiExample.populateFromRequest
          url: 'https://api.github.com/search/repositories?q=tetris+language:assembly&sort=stars&order=desc'
          headers:
            accept: "application/vnd.github.v3.text-match+json"

        expect(apiExample.version).toEqual("v3")

    describe 'when version is found in both URL and header', ->
      it 'takes the one from URL', ->
        apiExample.populateFromRequest
          url: "/v2/users"
          headers:
            'accept': 'application/vnd.github.v3.1+json'

        expect(apiExample.version).toEqual("v2")


    describe 'when version is given through x-spy-rest-version header', ->
      it 'overlooks URL and Accept header', ->
        apiExample.populateFromRequest
          headers:
            "x-spy-rest-version": "v1"
            "accept": "application/vnd.github.v3.1+json"
          url: "/v2/users"

        expect(apiExample.version).toEqual("v1")


  describe '#guessedResource', ->
    it 'guesses /users to users', ->
      apiExample.populateFromRequest
        url: '/users'
        headers: {}

      expect(apiExample.resource).toEqual("users")

    it 'guesses /users.json to users', ->
      apiExample.populateFromRequest
        url: '/users.json'
        headers: {}

      expect(apiExample.resource).toEqual("users")

    it 'guesses /users/10 to users', ->
      apiExample.populateFromRequest
        url: '/users/10'
        headers: {}

      expect(apiExample.resource).toEqual("users")

    it 'guesses /users/10/repos to repos', ->
      apiExample.populateFromRequest
        url: '/users/10/repos'
        headers: {}

      expect(apiExample.resource).toEqual("repos")

    it 'guesses /users/10/100/1000 to users', ->
      apiExample.populateFromRequest
        url: '/users/10/100/1000'
        headers: {}

      expect(apiExample.resource).toEqual("users")

    it 'overlooks the url in case the x-spy-rest-resource header is present', ->
      apiExample.populateFromRequest
        url: '/users/10/100/1000'
        headers:
          "x-spy-rest-resource": 'person'

      expect(apiExample.resource).toEqual("person")

  describe '#query', ->
    it 'is parsed from the url', ->
      apiExample.populateFromRequest
        url: '/users?page=1'
        headers:
          "x-spy-rest-resource": 'person'

      expect(apiExample.query).toEqual({page: '1'})

  describe '#digest', ->
    it 'computes the digest based on description, resource, version and full url', ->
      apiExample.description = 'a'
      apiExample.resource = 'b'
      apiExample.version = 'v1'
      apiExample.fullURL = 'https://p/q?a=1'

      digest = apiExample.computeDigest()

      apiExample.fullURL = "https://p/q?a=2"
      digest_2 = apiExample.computeDigest()

      expect(digest).not.toEqual(digest_2)









