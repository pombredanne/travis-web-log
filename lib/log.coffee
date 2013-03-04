@Log = (engine)->
  @listeners = []
  @engine = new (engine || Log.Dom)(@)
  @
$.extend Log,
  DEBUG: false
  create: (options) ->
    log = new Log(options.engine)
    log.listeners.push(listener) for listener in options.listeners || []
    log
$.extend Log.prototype,
  trigger: () ->
    args = Array::slice.apply(arguments)
    event = args[0]
    # @trigger('start', event) unless event == 'start' || event == 'stop'
    for listener in @listeners
      result = listener.notify.apply(listener, [@].concat(args))
      element = result if result?.hasChildNodes # ugh.
    # @trigger('stop', event) unless event == 'start' || event == 'stop'
    element
  set: (num, string) ->
    @trigger('receive', num, string)
    # Ember.run.next @, =>
    @engine.set(num, string)

Log.Listener = ->
$.extend Log.Listener.prototype,
  notify: (log, event, num) ->
    @[event].apply(@, [log].concat(Array::slice.call(arguments, 2))) if @[event]

# require 'log/buffer'
require 'log/deansi'
require 'log/engine/dom'
# require 'log/engine/chunks'
# require 'log/engine/live'
require 'log/folds'
require 'log/instrument'
require 'log/renderer/fragment'
# require 'log/renderer/inner_html'
# require 'log/renderer/jquery'

