Log.Node = (id, num) ->
  @id = id
  @num = num
  @key = Log.Node.key(@id)
  @children = new Log.Nodes(@)
  @
Log.extend Log.Node,
  key: (id) ->
    id.split('-').map((i) -> '000000'.concat(i).slice(-6)).join('') if id
Log.extend Log.Node.prototype,
  addChild: (node) ->
    @children.add(node)
  remove: () ->
    @log.remove(@element)
    @parent.children.remove(@)
Log.Node::__defineGetter__ 'log',        -> @_log ||= @parent?.log || @parent
Log.Node::__defineGetter__ 'firstChild', -> @children.first
Log.Node::__defineGetter__ 'lastChild',  -> @children.last


Log.Nodes = (parent) ->
  @parent = parent if parent
  @items  = []
  @index  = {}
  @
Log.extend Log.Nodes.prototype,
  add: (item) ->
    ix = @position(item) || 0
    @items.splice(ix, 0, item)
    item.parent = @parent if @parent
    prev = (item) -> item = item.prev while item && !item.children.last; item?.children.last
    next = (item) -> item = item.next while item && !item.children.first; item?.children.first
    item.prev.next = item if item.prev = @items[ix - 1] || prev(@parent?.prev)
    item.next.prev = item if item.next = @items[ix + 1] || next(@parent?.next)
    item
  remove: (item) ->
    @items.splice(@items.indexOf(item), 1)
    item.next.prev = item.prev if item.next
    item.prev.next = item.next if item.prev
    @parent.remove() if @items.length == 0
  position: (item) ->
    for ix in [@items.length - 1..0] by -1
      return ix + 1 if @items[ix].key < item.key
  indexOf: ->
    @items.indexOf.apply(@items, arguments)
  slice: ->
    @items.slice.apply(@items, arguments)
  each: (func) ->
    @items.slice().forEach(func)
  map: (func) ->
    @items.map(func)
Log.Nodes::__defineGetter__ 'first',  -> @items[0]
Log.Nodes::__defineGetter__ 'last',   -> @items[@length - 1]
Log.Nodes::__defineGetter__ 'length', -> @items.length


Log.Part = (id, num, string) ->
  Log.Node.apply(@, arguments)
  @string = string || ''
  @strings = @string.replace(/\r+\n/gm, '\n').split(/^/gm) || []
  @slices = (@strings.splice(0, Log.SLICE) while @strings.length > 0)
  @
Log.extend Log.Part,
  create: (log, num, string) ->
    part = new Log.Part(num.toString(), num, string)
    log.addChild(part)
    part.process(0, -1)
Log.Part.prototype = Log.extend new Log.Node,
  remove: ->
    # don't remove parts
  process: (slice, num) ->
    for string in (@slices[slice] || [])
      # return if @log.limit?.limited
      if fold = string.match(Log.FOLD)
        Log.Fold.render(@, "#{@id}-#{num += 1}", num, fold[1], fold[2])
      else
        for node in Log.Deansi.apply(string)
          Log.Span.render(@, "#{@id}-#{num += 1}", num, node.text, node.class)
        line = @children.first?.line
        line.clear() if line?.cr
    setTimeout((=> @process(slice + 1, num)), Log.TIMEOUT) unless slice >= @slices.length - 1


Log.Span = (id, num, text, classes) ->
  Log.Node.apply(@, arguments)
  @text  = text.replace(/.*\r/gm, '').replace(/\n$/, '')
  @nl    = !!text[text.length - 1]?.match(/\n/)
  @cr    = !!text.match(/\r/)
  @class = @cr && ['clears'] || classes
  @
Log.extend Log.Span,
  create: (parent, id, num, text, classes) ->
    span = new Log.Span(id, num, text, classes)
    parent.addChild(span)
    span
  render: (parent, id, num, text, classes) ->
    span = @create(parent, id, num, text, classes)
    span.render()
Log.Span.prototype = Log.extend new Log.Node,
  render: ->
    if false && !@nl && @next?.cr && @isSequence(@next)
      console.log "S.0 skip #{@id}" if Log.DEBUG
      @line = @next.line
      @remove()
    else if @prev && @prev.line && !@prev.nl
      console.log "S.1 insert #{@id} after prev #{@prev.id}" if Log.DEBUG
      @log.insert(@data, after: @prev.element)
      @line = @prev.line
    else if @next && @next.line # && !@nl
      console.log "S.2 insert #{@id} before next #{@next.id}" if Log.DEBUG
      @log.insert(@data, before: @next.element)
      @line = @next.line
    else
      @line = Log.Line.create(@log, [@])
      @line.render()
    # console.log format document.firstChild.innerHTML + '\n'

    @split(tail)  if @nl && (tail = @tail).length > 0

  remove: ->
    Log.Node::remove.apply(@)
    @line.remove(@) if @line
  split: (spans) ->
    console.log "S.3 split [#{spans.map((span) -> span.id).join(', ')}]" if Log.DEBUG
    @log.remove(span.element) for span in spans
    Log.Line.create(@log, spans).render()
  clear: ->
    if @prev && @isSibling(@prev) && @isSequence(@prev)
      @prev.clear()
      @prev.remove()
  isSequence: (other) ->
    @parent.num - other.parent.num == @log.children.indexOf(@parent) - @log.children.indexOf(other.parent)
  isSibling: (other) ->
    @element?.parentNode == other.element?.parentNode
  siblings: (type) ->
    siblings = []
    siblings.push(span) while (span = (span || @)[type]) && @isSibling(span)
    siblings
Log.Span::__defineSetter__ 'line', (line) ->
  @line.remove(@) if @line
  @_line = line
  @line.add(@)
Log.Span::__defineGetter__ 'data',    -> { id: @id, type: 'span', text: @text, class: @class}
Log.Span::__defineGetter__ 'line',    -> @_line
Log.Span::__defineGetter__ 'element', -> document.getElementById(@id)
Log.Span::__defineGetter__ 'head',    -> @siblings('prev').reverse()
Log.Span::__defineGetter__ 'tail',    -> @siblings('next')


Log.Fold = (id, num, event, name) ->
  Log.Node.apply(@, arguments)
  @fold  = true
  @event = event
  @name  = name
  @data  = { type: 'fold', id: @id, event: event, name: name }
  @
Log.extend Log.Fold,
  create: (parent, id, num, event, name) ->
    fold = new Log.Fold(id, num, event, name)
    parent.addChild(fold)
    fold
  render: (parent, id, num, event, name) ->
    fold = @create(parent, id, num, event, name)
    fold.render()
    fold.active = parent.log.folds.add(fold.data)
Log.Fold.prototype = Log.extend new Log.Node,
  render: ->
    if @prev
      console.log "F.1 insert #{@id} after prev #{@prev.id}" if Log.DEBUG
      element = @prev.fold && @prev.element || @prev.element.parentNode
      @element = @log.insert(@data, after: element)
    else if @next
      console.log "F.2 insert #{@id} before next #{@next.id}" if Log.DEBUG
      element = @next.fold && @next.element || @next.element.parentNode
      @element = @log.insert(@data, before: element)
    else
      console.log "F.3 insert #{@id}" if Log.DEBUG
      @element = @log.insert(@data)
    # console.log format document.firstChild.innerHTML + '\n'


Log.Line = (log) ->
  @log = log
  @spans = []
  @
Log.extend Log.Line,
  create: (log, spans) ->
    line = new Log.Line(log)
    span.line = line for span in spans
    line
Log.extend Log.Line.prototype,
  add: (span) ->
    @cr = true if span.cr
    if @spans.indexOf(span) > -1
      return
    else if (ix = @spans.indexOf(span.prev)) > -1
      @spans.splice(ix + 1, 0, span)
    else if (ix = @spans.indexOf(span.next)) > -1
      @spans.splice(ix, 0, span)
    else
      @spans.push(span)
  remove: (span) ->
    @spans.splice(ix, 1) if (ix = @spans.indexOf(span)) > -1
  render: ->
    if (fold = @prev) && fold.event == 'start' && fold.active
      console.log "P.1 insert #{@id} into fold #{fold.id}" if Log.DEBUG
      fold = @log.folds.folds[fold.name].fold
      @element = @log.insert(@data, into: fold)
    else if @prev
      console.log "L.1 insert #{@spans[0].id} after prev #{@prev.id}" if Log.DEBUG
      @element = @log.insert(@data, after: @prev.element)
    else if @next
      console.log "L.2 insert #{@spans[0].id} before next #{@next.id}" if Log.DEBUG
      @element = @log.insert(@data, before: @next.element)
    else
      console.log "L.3 insert #{@spans[0].id} into #log" if Log.DEBUG
      @element = @log.insert(@data)
    # console.log format document.firstChild.innerHTML + '\n'
  clear: ->
    # span.remove() for span in @head(cr) if cr = @crs.pop()
    cr.clear() if cr = @crs.pop()
  # head: (span) ->
  #   head = []
  #   head.push(span = span.prev) while span.prev && span.prev.line == @ && span.isSequence(span.prev)
  #   head

Log.Line::__defineGetter__ 'id',   -> @spans[0]?.id
Log.Line::__defineGetter__ 'data', -> { type: 'paragraph', nodes: @spans.map (span) -> span.data }
Log.Line::__defineGetter__ 'prev', -> span = @spans[0].prev; span?.fold && span || span?.line
Log.Line::__defineGetter__ 'next', -> span = @spans[@spans.length - 1].next; span?.fold && span || span?.line
Log.Line::__defineGetter__ 'crs',  -> @spans.filter (span) -> span.cr
