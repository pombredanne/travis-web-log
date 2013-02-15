window.App = Ember.Application.create
  rootElement: '#application'

App.MetricsRenderer = (controller) ->
  @controller = controller
  @
App.MetricsRenderer.prototype = $.extend new Log.Listener,
  stop: (log) ->
    metrics = log.metrics.summary()
    metrics = for key, metric of metrics
      avg = parseFloat(Math.round(metric.avg * 100) / 100).toFixed(4)
      "#{key}: count: #{metric.count} avg: #{avg}"
    @controller.set('metrics', metrics)

App.Runner = Em.Object.extend
  logs: {}

  start: (controller, options) ->
    console.log 'Start, options: ', options
    @set('running', true)
    @controller = controller
    @options = options
    @reset()
    @fetch(@handle)

  stop: ->
    @set('running', false)

  fetch: (handler) ->
    url = "https://api.travis-ci.org/jobs/#{@options.jobId}/log.txt"
    if @logs[url]
      handler.call(@, @logs[url])
    else
      @set('loading', true)
      $.get url, (log) =>
        @set('loading', false)
        @logs[url] = log
        handler.call(@, log)

  handle: (string) ->
    if @options.partition || @options.randomize
      parts = @split(string)
      if @options.stream
        @stream(parts)
      else
        @receive(part[0], part[1]) for part in parts
        @stop()
    else
      @receive 0, string
      @stop()

  receive: (ix, line) ->
    @log.set(ix, line) if @get('running')

  stream: (parts) ->
    wait = 0
    setTimeout((=> @receive.apply(@, arguments)), wait += @options.interval, part[0], part[1]) for part in parts
    setTimeout((=> @stop()), wait)

  reset: ->
    @clear()
    log = new Log
    log.listeners.push(new Log.Instrumenter)
    log.listeners.push(new App.MetricsRenderer(@controller))
    log.listeners.push(new Log[@options.renderer])
    @log = @options.buffer && new Log.Buffer(log) || log

  clear: ->
    $('#log').empty()

  split: (string) ->
    lines = string.split(/^/m)
    parts = ([i, line] for line, i in lines)
    parts = @slice(parts)     if @options.slice
    parts = @randomize(parts) if @options.randomize
    parts = @partition(parts) if false && @options.partition
    parts

  slice: (array) ->
    array.slice(0, @options.slice)

  partition: (parts) ->
    step = @rand(10)

    # randomly split some of the parts into more parts
    for _, i in Array::slice.apply(parts) by step
      if @rand(10) > 7.5
        split = @splitRand(parts[i][1], 5).map((chunk) -> [0, chunk])
        parts.splice.apply(parts, [i, 1].concat(split))

    # randomly join some of the parts into multi-line ones
    for _, i in Array::slice.apply(parts) by step
      if @rand(10) > 7.5
        count  = @rand(10)
        joined = ''
        joined += part[1] for part in parts.slice(i, count)
        parts.splice(i, count, joined)

    @renumber(parts)

  renumber: (parts) ->
    num = 0
    parts[i][0] = num += 1 for _, i in parts
    parts

  randomize: (array, step) ->
    @shuffle(array, i, step) for _, i in array by step
    array

  splitRand: (string, count) ->
    size  = (string.length / count) * 1.5
    split = []
    while string.length > 0
      count = @rand(size) + 1
      split.push(string.slice(0, count))
      string = string.slice(count)
    split

  rand: (num) ->
    Math.floor(Math.random() * num)

  shuffle: (array, start, count) ->
    for _, i in array.slice(start, start + count)
      j = start + @rand(i + 1)
      i = start + i
      tmp = array[i]
      array[i] = array[j]
      array[j] = tmp

App.ApplicationController = Em.Controller.extend
  jobId: 4754461
  randomize: true
  partition: true
  slice: 500
  stream: true
  buffer: true
  interval: 10
  runningBinding: 'runner.running'
  loadingBinding: 'runner.loading'

  renderers: [
    Em.Object.create(name: 'FragmentRenderer')
    Em.Object.create(name: 'JqueryRenderer'  )
  ]

  init: ->
    @_super.apply this, arguments
    @set 'runner', App.Runner.create()
    # @start()

  start: ->
    @get('runner').start @,
      jobId: @get('jobId')
      slice: parseInt(@get('slice'))
      interval: parseInt(@get('interval'))
      stream: @get('stream')
      buffer: @get('buffer')
      randomize: @get('randomize')
      partition: @get('partition')
      renderer: @get('renderer')

  stop: ->
    @get('runner').stop()

  toggleText: (->
    if @get('running') then 'Stop' else 'Start'
  ).property('running')

  toggle: ->
    @get('running') && @stop() || @start()

  clear: ->
    @get('runner').clear()

$ ->
  $('#log').on 'mouseenter', 'a', ->
    num = $(this.parentNode).prevAll('p').length + 1
    url = window.location + ''
    $(this).attr('href', url.replace(/#L\d+|(?=\?)|$/, '#L' + num))
  $('#log .fold-start + p').on 'click', ->
    $(this).prev().toggleClass('open')

