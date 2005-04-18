package HTML::Prototype;

use strict;
use base 'Class::Accessor::Fast';

our $VERSION = '1.20';
our $prototype = do { local $/; <DATA> };
my $callbacks = [qw/uninitialized loading loaded interactive complete/];

=head1 NAME

HTML::Prototype - Generate HTML and Javascript for the Prototype library

=head1 SYNOPSIS

    use HTML::Prototype;

    my $prototype = HTML::Prototype->new;
    print $prototype->define_javascript_functions;
    print $prototype->form_remote_tag(...);
    print $prototype->link_to_function(...);
    print $prototype->link_to_remote(...);
    print $prototype->observe_field(...);
    print $prototype->observe_form(...);
    print $prototype->periodically_call_remote(...);
    print $prototype->submit_to_remote(...);

=head1 DESCRIPTION

Some code generators for Prototype, the famous JavaScript OO library.

This is mostly a port of the Ruby on Rails helper tags for JavaScript
for use in L<Catalyst>.

=head2 METHODS

=head3 $prototype->define_javascript_functions

Returns the library of JavaScript functions and objects, in a script block.

Notes for L<Catalyst> users:

You can use C<script/create.pl Prototype> to generate a static JavaScript
file which then can be included via remote C<script> tag.

=cut

sub define_javascript_functions {
    return <<"";
<script type="text/javascript">
<!--
$prototype
//-->
</script>

}

=head3 $prototype->form_remote_tag(\%options)

Returns a form tag that will submit in the background using XMLHttpRequest,
instead of the regular reloading POST arrangement.

Even though it's using JavaScript to serialize the form elements,
the form submission will work just like a regular submission as viewed
by the receiving side.

The options for specifying the target with C<url> and defining callbacks is the same as C<link_to_remote>.

=cut

sub form_remote_tag {
    my ( $self, $options ) = @_;
    $options->{form} = 1;
    my $code = _remote_function($options);
    return qq/<form onsubmit="$code; return false;">/;
}

=head3 $prototype->link_to_function( $name, $function )

Returns a link that will trigger a JavaScript function using the onClick
handler and return false after the fact.

Examples:

    $prototype->link_to_function( "Greeting", "alert('Hello world!') )
    $prototype->link_to_function( '<img src="really.png"/>', 'do_delete()' )

=cut

sub link_to_function {
    my ( $self, $name, $function ) = @_;
    return qq|<a href="#" onClick="$function; return false;">$name</a>|;
}

=head3 $prototype->link_to_remote( $id, \%options )

Returns a link to a remote action defined by options C<url> that's
called in the background using XMLHttpRequest.

The result of that request can then be inserted into a DOM object whose
id can be specified with options->{update}.

Examples:

    $prototype->link_to_remote( 'Delete', {
        update => 'posts',
        url    => 'http://localhost/posts/'
    } )

    $prototype->link_to_remote( '<img src="refresh.png"/>', {
        update => 'emails',
        url    => 'http://localhost/refresh/'
    } )

By default, these remote requests are processed asynchronously, during
which various callbacks can be triggered (e.g. for progress indicators
and the like).

Example:

    $prototype->link_to_remote( 'count', {
        url => 'http://localhost/count/',
        complete => 'doStuff(request)'
    } )

The callbacks that may be specified are:

C<loading>: Called when the remote document is being loaded with data
by the browser.

C<loaded>: Called when the browser has finished loading the remote document.

C<interactive>: Called when the user can interact with the remote document,
even though it has not finished loading.

C<complete>: Called when the XMLHttpRequest is complete.

If you do need synchronous processing
(this will block the browser while the request is happening),
you can specify $options->{type} = 'synchronous'.

=cut

sub link_to_remote {
    my ( $self, $id, $options ) = @_;
    $self->link_to_function( $id, _remote_function($options) );
}

=head3 $prototype->observe_field( $id, \%options)

Observes the field with the DOM ID specified by $id and makes an
Ajax when its contents have changed.

Required options are:

C<frequency>: The frequency (in seconds) at which changes to this field
will be detected.

C<url>: url to be called when field content has changed.

Additional options are:

C<update>: Specifies the DOM ID of the element whose innerHTML
should be updated with the XMLHttpRequest response text.

C<with>: A JavaScript expression specifying the parameters for the
XMLHttpRequest.
This defaults to value, which in the evaluated context refers to the
new field value.

Additionally, you may specify any of the options documented in
C<link_to_remote>.

Example TT2 template in L<Catalyst>:

    [% c.prototype.define_javascript_functions %]
    <h1>[% page.title %]</h1>
    <div id="view"></div>
    <textarea id="editor" rows="24" cols="80">[% page.body %]</textarea>
    [% url = base _ 'edit/' _ page.title %]
    [% c.prototype.observe_field( 'editor', {
        url    => url,
        with   => "'body='+value",
        update => 'view'
    } ) %]

=cut

sub observe_field {
    my ( $self, $id, $options ) = @_;
    _build_observer( 'Form.Element.Observer', $id, $options );
}

=head3 $prototype->observe_form( $id, \%options )

Like C<observe_field>, but operates on an entire form identified by
the DOM ID $id.

Options are the same as C<observe_field>, except the default value of
the C<with> option evaluates to the serialized (request string) value
of the form.

=cut

sub observe_form {
    my ( $self, $id, $options ) = @_;
    _build_observer( 'Form.Observer', $id, $options );
}

=head3 $prototype->periodically_call_remote( \%options )

Periodically calls the specified url $options->{url}  every
$options->{frequency} seconds (default is 10).

Usually used to update a specified div $options->{update} with the
results of the remote call.

The options for specifying the target with C<url> and defining
callbacks is the same as C<link_to_remote>.

=cut

sub periodically_call_remote {
    my ( $self, $options ) = @_;
    my $frequency = $options->{frequency} || 10;
    my $code = _remote_function($options);
    return <<"";
<script type="text/javascript">
<!--
new PeriodicalExecuter( function () { $code }, $frequency );
//-->
</script>

}

=head3 $prototype->submit_to_remote( $name, $value, \%options )

Returns a button input tag that will submit a form using XMLHttpRequest
in the background instead of a typical reloading via POST.

C<options> argument is the same as in C<form_remote_tag>

=cut

sub submit_to_remote {
    my ( $self, $name, $value, $options ) = @_;
    my $code = _remote_function($options);
    $code = "$code; return false;";
    return
      qq|<input type="button" name="$name" value="$value" onsubmit="$code"/>|;
}

sub _build_callbacks {
    my $options = shift;
    my %callbacks;
    for my $callback (@$callbacks) {
        if ( my $code = $options->{$callback} ) {
            my $name = 'on' . ucfirst $callback;
            $callbacks{$name} = "function(request){$code}";
        }
    }
    return \%callbacks;
}

sub _build_observer {
    my ( $class, $name, $options ) = @_;
    $options->{with} ||= 'value' if $options->{update};
    my $freq = $options->{frequency} || 2;
    my $callback = _remote_function($options);
    return <<"";
<script type="text/javascript">
<!--
new $class( '$name', $freq, function( element, value ) { $callback } );
//-->
</script>

}

sub _options_for_ajax {
    my $options    = shift;
    my $js_options = _build_callbacks($options);
    $options->{type} ||= '';
    $js_options->{asynchronous} = $options->{type} eq 'synchronous' ? 0 : 1;
    $js_options->{method} = $options->{method} if $options->{method};
    my $position = $options->{position};
    $js_options->{insertion} = "Insertion.$position" if $position;
    if ( $options->{form} ) {
        $js_options->{parameters} = 'Form.serialize(this)';
    }
    elsif ( $options->{with} ) {
        $js_options->{parameters} = $options->{with};
    }
    return '{ '
      . join( ',', map { "$_: " . $js_options->{$_} } keys %$js_options )
      . ' }';
}

sub _remote_function {
    my $options    = shift;
    my $js_options = _options_for_ajax($options);
    my $update     = $options->{update};
    my $function   =
      $update ? " new Ajax.Updater( '$update', " : ' new Ajax.Request( ';
    my $url = $options->{url} || '';
    $function .= " '$url', $js_options ) ";
    my $before = $options->{before};
    $function = "$before; $function " if $before;
    my $after = $options->{after};
    $function = "$function; $after;" if $after;
    my $condition = $options->{condition};
    $function = "if ($condition) { $function; }" if $condition;
    return $function;
}

=head1 SEE ALSO

L<Catalyst::Plugin::Prototype>, L<Catalyst>.

=head1 AUTHOR

Sebastian Riedel, C<sri@oook.de>

Built around Prototype by Sam Stephenson.
Much code is ported from Ruby on Rails javascript helpers.

=head1 THANK YOU

Drew Taylor, Leon Brocard

=head1 LICENSE

This library is free software. You can redistribute it and/or modify it under
the same terms as perl itself.

=cut

1;
__DATA__
/*  Prototype: an object-oriented Javascript library, version 1.2.0
 *  (c) 2005 Sam Stephenson <sam@conio.net>
 *
 *  THIS FILE IS AUTOMATICALLY GENERATED. When sending patches, please diff
 *  against the source tree, available from the Prototype darcs repository. 
 *
 *  Prototype is freely distributable under the terms of an MIT-style license.
 *
 *  For details, see the Prototype web site: http://prototype.conio.net/
 *
/*--------------------------------------------------------------------------*/

var Prototype = {
  Version: '1.2.0'
}

var Class = {
  create: function() {
    return function() { 
      this.initialize.apply(this, arguments);
    }
  }
}

var Abstract = new Object();

Object.prototype.extend = function(object) {
  for (property in object) {
    this[property] = object[property];
  }
  return this;
}

Function.prototype.bind = function(object) {
  var method = this;
  return function() {
    method.apply(object, arguments);
  }
}

Function.prototype.bindAsEventListener = function(object) {
  var method = this;
  return function(event) {
    method.call(object, event || window.event);
  }
}

Number.prototype.toColorPart = function() {
  var digits = this.toString(16);
  if (this < 16) return '0' + digits;
  return digits;
}

var Try = {
  these: function() {
    var returnValue;
    
    for (var i = 0; i < arguments.length; i++) {
      var lambda = arguments[i];
      try {
        returnValue = lambda();
        break;
      } catch (e) {}
    }
    
    return returnValue;
  }
}

/*--------------------------------------------------------------------------*/

var PeriodicalExecuter = Class.create();
PeriodicalExecuter.prototype = {
  initialize: function(callback, frequency) {
    this.callback = callback;
    this.frequency = frequency;
    this.currentlyExecuting = false;
    
    this.registerCallback();
  },
  
  registerCallback: function() {
    setTimeout(this.onTimerEvent.bind(this), this.frequency * 1000);
  },
  
  onTimerEvent: function() {
    if (!this.currentlyExecuting) {
      try { 
        this.currentlyExecuting = true;
        this.callback(); 
      } finally { 
        this.currentlyExecuting = false;
      }
    }
    
    this.registerCallback();
  }
}

/*--------------------------------------------------------------------------*/

function $() {
  var elements = new Array();
  
  for (var i = 0; i < arguments.length; i++) {
    var element = arguments[i];
    if (typeof element == 'string')
      element = document.getElementById(element);

    if (arguments.length == 1) 
      return element;
      
    elements.push(element);
  }
  
  return elements;
}

/*--------------------------------------------------------------------------*/

if (!Array.prototype.push) {
  Array.prototype.push = function() {
                var startLength = this.length;
                for (var i = 0; i < arguments.length; i++)
      this[startLength + i] = arguments[i];
          return this.length;
  }
}

if (!Function.prototype.apply) {
  // Based on code from http://www.youngpup.net/
  Function.prototype.apply = function(object, parameters) {
    var parameterStrings = new Array();
    if (!object)     object = window;
    if (!parameters) parameters = new Array();
    
    for (var i = 0; i < parameters.length; i++)
      parameterStrings[i] = 'x[' + i + ']';
    
    object.__apply__ = this;
    var result = eval('obj.__apply__(' + 
      parameterStrings[i].join(', ') + ')');
    object.__apply__ = null;
    
    return result;
  }
}

/*--------------------------------------------------------------------------*/

var Ajax = {
  getTransport: function() {
    return Try.these(
      function() {return new ActiveXObject('Msxml2.XMLHTTP')},
      function() {return new ActiveXObject('Microsoft.XMLHTTP')},
      function() {return new XMLHttpRequest()}
    ) || false;
  },
  
  emptyFunction: function() {}
}

Ajax.Base = function() {};
Ajax.Base.prototype = {
  setOptions: function(options) {
    this.options = {
      method:       'post',
      asynchronous: true,
      parameters:   ''
    }.extend(options || {});
  }
}

Ajax.Request = Class.create();
Ajax.Request.Events = 
  ['Uninitialized', 'Loading', 'Loaded', 'Interactive', 'Complete'];

Ajax.Request.prototype = (new Ajax.Base()).extend({
  initialize: function(url, options) {
    this.transport = Ajax.getTransport();
    this.setOptions(options);
  
    try {
      if (this.options.method == 'get')
        url += '?' + this.options.parameters + '&_=';
    
      this.transport.open(this.options.method, url, true);
      
      if (this.options.asynchronous) {
        this.transport.onreadystatechange = this.onStateChange.bind(this);
        setTimeout((function() {this.respondToReadyState(1)}).bind(this), 10);
      }
              
      this.transport.setRequestHeader('X-Requested-With', 'XMLHttpRequest');
      this.transport.setRequestHeader('X-Prototype-Version', Prototype.Version);

      if (this.options.method == 'post') {
        this.transport.setRequestHeader('Connection', 'close');
        this.transport.setRequestHeader('Content-type',
          'application/x-www-form-urlencoded');
      }
      
      this.transport.send(this.options.method == 'post' ? 
        this.options.parameters + '&_=' : null);
                      
    } catch (e) {
    }    
  },
      
  onStateChange: function() {
    var readyState = this.transport.readyState;
    if (readyState != 1)
      this.respondToReadyState(this.transport.readyState);
  },
  
  respondToReadyState: function(readyState) {
    var event = Ajax.Request.Events[readyState];
    (this.options['on' + event] || Ajax.emptyFunction)(this.transport);
  }
});

Ajax.Updater = Class.create();
Ajax.Updater.prototype = (new Ajax.Base()).extend({
  initialize: function(container, url, options) {
    this.container = $(container);
    this.setOptions(options);
  
    if (this.options.asynchronous) {
      this.onComplete = this.options.onComplete;
      this.options.onComplete = this.updateContent.bind(this);
    }
    
    this.request = new Ajax.Request(url, this.options);
    
    if (!this.options.asynchronous)
      this.updateContent();
  },
  
  updateContent: function() {
    if (this.options.insertion) {
      new this.options.insertion(this.container,
        this.request.transport.responseText);
    } else {
      this.container.innerHTML = this.request.transport.responseText;
    }

    if (this.onComplete) {
      setTimeout((function() {this.onComplete(this.request)}).bind(this), 10);
    }
  }
});

/*--------------------------------------------------------------------------*/

var Field = {
  clear: function() {
    for (var i = 0; i < arguments.length; i++)
      $(arguments[i]).value = '';
  },

  focus: function(element) {
    $(element).focus();
  },
  
  present: function() {
    for (var i = 0; i < arguments.length; i++)
      if ($(arguments[i]).value == '') return false;
    return true;
  },
  
  select: function(element) {
    $(element).select();
  },
   
  activate: function(element) {
    $(element).focus();
    $(element).select();
  }
}

/*--------------------------------------------------------------------------*/

var Form = {
  serialize: function(form) {
    var elements = Form.getElements($(form));
    var queryComponents = new Array();
    
    for (var i = 0; i < elements.length; i++) {
      var queryComponent = Form.Element.serialize(elements[i]);
      if (queryComponent)
        queryComponents.push(queryComponent);
    }
    
    return queryComponents.join('&');
  },
  
  getElements: function(form) {
    form = $(form);
    var elements = new Array();

    for (tagName in Form.Element.Serializers) {
      var tagElements = form.getElementsByTagName(tagName);
      for (var j = 0; j < tagElements.length; j++)
        elements.push(tagElements[j]);
    }
    return elements;
  },
  
  disable: function(form) {
    var elements = Form.getElements(form);
    for (var i = 0; i < elements.length; i++) {
      var element = elements[i];
      element.blur();
      element.disable = 'true';
    }
  },

  focusFirstElement: function(form) {
    form = $(form);
    var elements = Form.getElements(form);
    for (var i = 0; i < elements.length; i++) {
      var element = elements[i];
      if (element.type != 'hidden' && !element.disabled) {
        Field.activate(element);
        break;
      }
    }
  },

  reset: function(form) {
    $(form).reset();
  }
}

Form.Element = {
  serialize: function(element) {
    element = $(element);
    var method = element.tagName.toLowerCase();
    var parameter = Form.Element.Serializers[method](element);
    
    if (parameter)
      return encodeURIComponent(parameter[0]) + '=' + 
        encodeURIComponent(parameter[1]);                   
  },
  
  getValue: function(element) {
    element = $(element);
    var method = element.tagName.toLowerCase();
    var parameter = Form.Element.Serializers[method](element);
    
    if (parameter) 
      return parameter[1];
  }
}

Form.Element.Serializers = {
  input: function(element) {
    switch (element.type.toLowerCase()) {
      case 'hidden':
      case 'password':
      case 'text':
        return Form.Element.Serializers.textarea(element);
      case 'checkbox':  
      case 'radio':
        return Form.Element.Serializers.inputSelector(element);
    }
    return false;
  },

  inputSelector: function(element) {
    if (element.checked)
      return [element.name, element.value];
  },

  textarea: function(element) {
    return [element.name, element.value];
  },

  select: function(element) {
    var index = element.selectedIndex;
    var value = element.options[index].value || element.options[index].text;
    return [element.name, (index >= 0) ? value : ''];
  }
}

/*--------------------------------------------------------------------------*/

var $F = Form.Element.getValue;

/*--------------------------------------------------------------------------*/

Abstract.TimedObserver = function() {}
Abstract.TimedObserver.prototype = {
  initialize: function(element, frequency, callback) {
    this.frequency = frequency;
    this.element   = $(element);
    this.callback  = callback;
    
    this.lastValue = this.getValue();
    this.registerCallback();
  },
  
  registerCallback: function() {
    setTimeout(this.onTimerEvent.bind(this), this.frequency * 1000);
  },
  
  onTimerEvent: function() {
    var value = this.getValue();
    if (this.lastValue != value) {
      this.callback(this.element, value);
      this.lastValue = value;
    }
    
    this.registerCallback();
  }
}

Form.Element.Observer = Class.create();
Form.Element.Observer.prototype = (new Abstract.TimedObserver()).extend({
  getValue: function() {
    return Form.Element.getValue(this.element);
  }
});

Form.Observer = Class.create();
Form.Observer.prototype = (new Abstract.TimedObserver()).extend({
  getValue: function() {
    return Form.serialize(this.element);
  }
});


/*--------------------------------------------------------------------------*/

document.getElementsByClassName = function(className) {
  var children = document.getElementsByTagName('*') || document.all;
  var elements = new Array();
  
  for (var i = 0; i < children.length; i++) {
    var child = children[i];
    var classNames = child.className.split(' ');
    for (var j = 0; j < classNames.length; j++) {
      if (classNames[j] == className) {
        elements.push(child);
        break;
      }
    }
  }
  
  return elements;
}

/*--------------------------------------------------------------------------*/

var Element = {
  toggle: function() {
    for (var i = 0; i < arguments.length; i++) {
      var element = $(arguments[i]);
      element.style.display = 
        (element.style.display == 'none' ? '' : 'none');
    }
  },

  hide: function() {
    for (var i = 0; i < arguments.length; i++) {
      var element = $(arguments[i]);
      element.style.display = 'none';
    }
  },

  show: function() {
    for (var i = 0; i < arguments.length; i++) {
      var element = $(arguments[i]);
      element.style.display = '';
    }
  },

  remove: function(element) {
    element = $(element);
    element.parentNode.removeChild(element);
  },
   
  getHeight: function(element) {
    element = $(element);
    return element.offsetHeight; 
  }
}

var Toggle = new Object();
Toggle.display = Element.toggle;

/*--------------------------------------------------------------------------*/

Abstract.Insertion = function(adjacency) {
  this.adjacency = adjacency;
}

Abstract.Insertion.prototype = {
  initialize: function(element, content) {
    this.element = $(element);
    this.content = content;
    
    if (this.adjacency && this.element.insertAdjacentHTML) {
      this.element.insertAdjacentHTML(this.adjacency, this.content);
    } else {
      this.range = this.element.ownerDocument.createRange();
      if (this.initializeRange) this.initializeRange();
      this.fragment = this.range.createContextualFragment(this.content);
      this.insertContent();
    }
  }
}

var Insertion = new Object();

Insertion.Before = Class.create();
Insertion.Before.prototype = (new Abstract.Insertion('beforeBegin')).extend({
  initializeRange: function() {
    this.range.setStartBefore(this.element);
  },
  
  insertContent: function() {
    this.element.parentNode.insertBefore(this.fragment, this.element);
  }
});

Insertion.Top = Class.create();
Insertion.Top.prototype = (new Abstract.Insertion('afterBegin')).extend({
  initializeRange: function() {
    this.range.selectNodeContents(this.element);
    this.range.collapse(true);
  },
  
  insertContent: function() {  
    this.element.insertBefore(this.fragment, this.element.firstChild);
  }
});

Insertion.Bottom = Class.create();
Insertion.Bottom.prototype = (new Abstract.Insertion('beforeEnd')).extend({
  initializeRange: function() {
    this.range.selectNodeContents(this.element);
    this.range.collapse(this.element);
  },
  
  insertContent: function() {
    this.element.appendChild(this.fragment);
  }
});

Insertion.After = Class.create();
Insertion.After.prototype = (new Abstract.Insertion('afterEnd')).extend({
  initializeRange: function() {
    this.range.setStartAfter(this.element);
  },
  
  insertContent: function() {
    this.element.parentNode.insertBefore(this.fragment, 
      this.element.nextSibling);
  }
});

/*--------------------------------------------------------------------------*/

var Effect = new Object();

Effect.Highlight = Class.create();
Effect.Highlight.prototype = {
  initialize: function(element) {
    this.element = $(element);
    this.start  = 153;
    this.finish = 255;
    this.current = this.start;
    this.fade();
  },
  
  fade: function() {
    if (this.isFinished()) return;
    if (this.timer) clearTimeout(this.timer);
    this.highlight(this.element, this.current);
    this.current += 17;
    this.timer = setTimeout(this.fade.bind(this), 250);
  },
  
  isFinished: function() {
    return this.current > this.finish;
  },
  
  highlight: function(element, current) {
    element.style.backgroundColor = "#ffff" + current.toColorPart();
  }
}


Effect.Fade = Class.create();
Effect.Fade.prototype = {
  initialize: function(element) {
    this.element = $(element);
    this.start  = 100;
    this.finish = 0;
    this.current = this.start;
    this.fade();
  },
  
  fade: function() {
    if (this.isFinished()) { this.element.style.display = 'none'; return; }
    if (this.timer) clearTimeout(this.timer);
    this.setOpacity(this.element, this.current);
    this.current -= 10;
    this.timer = setTimeout(this.fade.bind(this), 50);
  },
  
  isFinished: function() {
    return this.current <= this.finish;
  },
  
  setOpacity: function(element, opacity) {
    opacity = (opacity == 100) ? 99.999 : opacity;
    element.style.filter = "alpha(opacity:"+opacity+")";
    element.style.opacity = opacity/100 /*//*/;
  }
}

Effect.Scale = Class.create();
Effect.Scale.prototype = {
  initialize: function(element, percent) {
    this.element = $(element);
    this.startScale    = 1.0;
    this.startHeight   = this.element.offsetHeight;
    this.startWidth    = this.element.offsetWidth;
    this.currentHeight = this.startHeight;
    this.currentWidth  = this.startWidth;
    this.finishScale   = (percent/100) /*//*/;
    if (this.element.style.fontSize=="") this.sizeEm = 1.0;
    if (this.element.style.fontSize.indexOf("em")>0)
       this.sizeEm      = parseFloat(this.element.style.fontSize);
    if(this.element.effect_scale) {
      clearTimeout(this.element.effect_scale.timer);
      this.startScale  = this.element.effect_scale.currentScale;
      this.startHeight = this.element.effect_scale.startHeight;
      this.startWidth  = this.element.effect_scale.startWidth;
      if(this.element.effect_scale.sizeEm) 
        this.sizeEm    = this.element.effect_scale.sizeEm;      
    }
    this.element.effect_scale = this;
    this.currentScale  = this.startScale;
    this.factor        = this.finishScale - this.startScale;
    this.options       = arguments[2] || {}; 
    this.scale();
  },
  
  scale: function() {
    if (this.isFinished()) { 
      this.setDimensions(this.element, this.startWidth*this.finishScale, this.startHeight*this.finishScale);
      if(this.sizeEm) this.element.style.fontSize = this.sizeEm*this.finishScale + "em";
      if(this.options.complete) this.options.complete(this);
      return; 
    }
    if (this.timer) clearTimeout(this.timer);
    if (this.options.step) this.options.step(this);
    this.setDimensions(this.element, this.currentWidth, this.currentHeight);
    if(this.sizeEm) this.element.style.fontSize = this.sizeEm*this.currentScale + "em";
    this.currentScale += (this.factor/10) /*//*/;
    this.currentWidth = this.startWidth * this.currentScale;
    this.currentHeight = this.startHeight * this.currentScale;
    this.timer = setTimeout(this.scale.bind(this), 50);
  },
  
  isFinished: function() {
    return (this.factor < 0) ? 
      this.currentScale <= this.finishScale : this.currentScale >= this.finishScale;
  },
  
  setDimensions: function(element, width, height) {
    element.style.width = width + 'px';
    element.style.height = height + 'px';
  }
}

Effect.Squish = Class.create();
Effect.Squish.prototype = {
  initialize: function(element) {
    this.element = $(element);
    new Effect.Scale(this.element, 1, { complete: this.hide.bind(this) } );
  },
  hide: function() {
    this.element.style.display = 'none';
  } 
}

Effect.Puff = Class.create();
Effect.Puff.prototype = {
  initialize: function(element) {
    this.element = $(element);
    this.opacity = 100;
    this.startTop  = this.element.top || this.element.offsetTop;
    this.startLeft = this.element.left || this.element.offsetLeft;
    new Effect.Scale(this.element, 200, { step: this.fade.bind(this), complete: this.hide.bind(this) } );
  },
  fade: function(effect) {
    topd    = (((effect.currentScale)*effect.startHeight) - effect.startHeight)/2;
    leftd   = (((effect.currentScale)*effect.startWidth) - effect.startWidth)/2;
    this.element.style.position='absolute';
    this.element.style.top = this.startTop-topd + "px";
    this.element.style.left = this.startLeft-leftd + "px";
    this.opacity -= 10;
    this.setOpacity(this.element, this.opacity); 
    if(navigator.appVersion.indexOf('AppleWebKit')>0) this.element.innerHTML += ''; //force redraw on safari
  },
  hide: function() {
    this.element.style.display = 'none';
  },
  setOpacity: function(element, opacity) {
    opacity = (opacity == 100) ? 99.999 : opacity;
    element.style.filter = "alpha(opacity:"+opacity+")";
    element.style.opacity = opacity/100 /*//*/;
  }
}

Effect.Appear = Class.create();
Effect.Appear.prototype = {
  initialize: function(element) {
    this.element = $(element);
    this.start  = 0;
    this.finish = 100;
    this.current = this.start;
    this.fade();
  },
  
  fade: function() {
    if (this.isFinished()) return;
    if (this.timer) clearTimeout(this.timer);
    this.setOpacity(this.element, this.current);
    this.current += 10;
    this.timer = setTimeout(this.fade.bind(this), 50);
  },
  
  isFinished: function() {
    return this.current > this.finish;
  },
  
  setOpacity: function(element, opacity) {
    opacity = (opacity == 100) ? 99.999 : opacity;
    element.style.filter = "alpha(opacity:"+opacity+")";
    element.style.opacity = opacity/100 /*//*/;
    element.style.display = '';
  }
}

Effect.ContentZoom = Class.create();
Effect.ContentZoom.prototype = {
  initialize: function(element, percent) {
    this.element = $(element);
    if (this.element.style.fontSize=="") this.sizeEm = 1.0;
    if (this.element.style.fontSize.indexOf("em")>0)
       this.sizeEm = parseFloat(this.element.style.fontSize);
    if(this.element.effect_contentzoom) {
      this.sizeEm = this.element.effect_contentzoom.sizeEm;
    }
    this.element.effect_contentzoom = this;
    this.element.style.fontSize = this.sizeEm*(percent/100) + "em" /*//*/;
    if(navigator.appVersion.indexOf('AppleWebKit')>0) { this.element.scrollTop -= 1; };
  }
}
