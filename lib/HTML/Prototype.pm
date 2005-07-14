package HTML::Prototype;

use strict;
use base qw/Class::Accessor::Fast/;
use vars qw/$VERSION $prototype $controls $dragdrop $effects/;

$VERSION = '1.32';

use HTML::Element;
use HTML::Prototype::Js;
use HTML::Prototype::Controls;
use HTML::Prototype::DragDrop;
use HTML::Prototype::Effects;

$prototype = do { package HTML::Prototype::Js;       local $/; <DATA> };
$controls  = do { package HTML::Prototype::Controls; local $/; <DATA> };
$dragdrop  = do { package HTML::Prototype::DragDrop; local $/; <DATA> };
$effects   = do { package HTML::Prototype::Effects;  local $/; <DATA> };

my $callbacks    = [qw/uninitialized loading loaded interactive complete/];
my $ajax_options = [qw/url asynchronous method insertion form with/];

=head1 NAME

HTML::Prototype - Generate HTML and Javascript for the Prototype library

=head1 SYNOPSIS

    use HTML::Prototype;

    my $prototype = HTML::Prototype->new;
    print $prototype->auto_complete_field(...);
    print $prototype->auto_complete_result(...);
    print $prototype->auto_complete_stylesheet(...);
    print $prototype->content_tag(...);
    print $prototype->define_javascript_functions;
    print $prototype->draggable_element(...);
    print $prototype->drop_receiving_element(...);
    print $prototype->evaluate_remote_response(...);
    print $prototype->form_remote_tag(...);
    print $prototype->javascript_tag(...);
    print $prototype->link_to_function(...);
    print $prototype->link_to_remote(...);
    print $prototype->observe_field(...);
    print $prototype->observe_form(...);
    print $prototype->periodically_call_remote(...);
    print $prototype->sortable_element(...);
    print $prototype->submit_to_remote(...);
    print $prototype->tag(...);
    print $ptototype->update_element_function(...);
    print $prototype->visual_effect(...);

=head1 DESCRIPTION

Some code generators for Prototype, the famous JavaScript OO library
and the script.aculous extensions.

This library allows you to do Ajax without writing lots of JavaScript 
code.

This is mostly a port of the Ruby on Rails helper tags for JavaScript
for use in L<Catalyst>.

=head2 METHODS

=over 4

=item $prototype->auto_complete_field( $field_id, \%options )

Adds Ajax autocomplete functionality to the text input field with the
DOM ID specified by C<field_id>.

This function expects that the called action returns a HTML <ul> list,
or nothing if no entries should be displayed for autocompletion.
 
Required options are:

C<url>: Specifies the URL to be used in the AJAX call.

 
Addtional options are:

C<update>: Specifies the DOM ID of the element whose  innerHTML should
be updated with the autocomplete entries returned by the Ajax request.
Defaults to field_id + '_auto_complete'.

C<with>: A Javascript expression specifying the parameters for the
XMLHttpRequest.
This defaults to 'value', which in the evaluated context refers to the
new field value.

C<indicator>: Specifies the DOM ID of an elment which will be displayed
while autocomplete is running.

=cut

sub auto_complete_field {
    my ( $self, $id, $options ) = @_;
    $options ||= {};
    my $update = $options->{update} || "$id" . '_auto_complete';
    my $function =
      "new Ajax.Autocompleter( '$id', '$update', '" . $options->{url} . "'";

    my $js_options = {};
    $js_options->{callback} =
      ( 'function ( element, value ) { return ' . $options->{with} . ' }' )
      if $options->{with};
    $js_options->{indicator} = ( "'" . $options->{indicator} . "'" )
      if $options->{indicator};
    $function .= ',' . _options_for_javascript($js_options) . ')';
    $self->javascript_tag($function);
}

=item $prototype->auto_complete_result(\@items)

Returns a list, to communcate with the Autocompleter.

Here's an example for L<Catalyst>:

    sub autocomplete : Global {
        my ( $self, $c ) = @_;
        my @items = qw/foo bar baz/;
        $c->res->body( $c->prototype->auto_complete_result(\@items) );
    }

=cut

sub auto_complete_result {
    my ( $self, $items ) = @_;
    my @elements;
    for my $item (@$items) {
        push @elements, HTML::Element->new('li')->push_content($item);
    }
    return HTML::Element->new('ul')->push_content(@elements)->as_HTML;
}

=item $prototype->auto_complete_stylesheet

Returns the auto_complete stylesheet.

=cut

sub auto_complete_stylesheet {
    my $self = shift;
    return $self->content_tag( 'style', <<"");
    div.auto_complete {
        width: 350px;
        background: #fff;
    }
    div.auto_complete ul {
        border:1px solid #888;
        margin:0;
        padding:0;
        width:100%;
        list-style-type:none;
    }
    div.auto_complete ul li {
        margin:0;
        padding:3px;
    }
    div.auto_complete ul li.selected { 
        background-color: #ffb; 
    }
    div.auto_complete ul strong.highlight { 
        color: #800; 
        margin:0;
        padding:0;
    }

}

=item $prototype->content_tag( $name, $content, \%html_options )

Returns a block with opening tag, content, and ending tag. Useful for
autogenerating tags like B<<a href="http://catalyst.perl.org">Catalyst
Homepage</a>>. The first parameter is the tag name, i.e. B<'a'> or
B<'img'>.

=cut

sub content_tag {
    my ( $self, $name, $content, $html_options ) = @_;
    $html_options ||= {};
    my $tag = HTML::Element->new( $name, %$html_options );
    $tag->push_content($content);
    return $tag->as_HTML;
}

=item $prototype->define_javascript_functions

Returns the library of JavaScript functions and objects, in a script block.

Notes for L<Catalyst> users:

You can use C<script/myapp_create.pl Prototype> to generate a static JavaScript
file which then can be included via remote C<script> tag.

=cut

sub define_javascript_functions {
    return shift->javascript_tag("$prototype$controls$dragdrop$effects");
}

=item $prototype->draggable_element( $element_id, \%options )

Makes the element with the DOM ID specified by C<element_id> draggable.

Example:

    $prototype->draggable_element( 'my_image', { revert => 'true' } );

The available options are:

=over 4

=item handle

Default: none. Sets whether the element should only be draggable by an
embedded handle. The value is a string referencing a CSS class. The
first child/grandchild/etc. element found within the element that has
this CSS class will be used as the handle.

=item revert

Default: false. If set to true, the element returns to its original
position when the drags ends.

=item constraint

Default: none. If set to 'horizontal' or 'vertical' the drag will be
constrained to take place only horizontally or vertically.

=item change

Javascript callback function called whenever the Draggable is moved by
dragging. It should be a string whose contents is a valid JavaScript
function definition. The called function gets the Draggable instance
as its parameter. It might look something like this:

    'function (element) { // do something with dragged element }'

=back

See http://script.aculo.us for more documentation.

=cut

sub draggable_element {
    my ( $self, $element_id, $options ) = @_;
    $options ||= {};
    my $js_options = _options_for_javascript($options);
    return $self->javascript_tag("new Draggable( '$element_id', $js_options )");
}

=item $prototype->drop_receiving_element( $element_id, \%options )

Makes the element with the DOM ID specified by C<element_id> receive
dropped draggable elements (created by draggable_element).

And make an AJAX call.

By default, the action called gets the DOM ID of the element as parameter.

Example:
    $prototype->drop_receiving_element(
      'my_cart', { url => 'http://foo.bar/add' } );

Required options are:

=over 4

=item url

The URL for the AJAX call.

=back

Additional options are:

=over 4

=item accept

Default: none. Set accept to a string or an array of
strings describing CSS classes. The Droppable will only accept
Draggables that have one or more of these CSS classes.

=item containment

Default: none. The droppable will only accept the Draggable if the
Draggable is contained in the given elements (or element ids). Can be a
single element or an array of elements. This is option is used by
Sortables to control Drag-and-Drop between Sortables.

=item overlap

Default: none. If set to 'horizontal' or 'vertical' the droppable will
only react to a Draggable if it overlaps by more than 50% in the given
direction. Used by Sortables.

Additionally, the following JavaScript callback functions can be used
in the option parameter:

=item onHover

Javascript function called whenever a Draggable is moved over the
Droppable and the Droppable is affected (would accept it). The
callback gets three parameters: the Draggable, the Droppable element,
and the percentage of overlapping as defined by the overlap
option. Used by Sortables. The function might look something like
this:

    'function (draggable, droppable, pcnt) { // do something }'

=back

See http://script.aculo.us for more documentation.

=cut

sub drop_receiving_element {
    my ( $self, $element_id, $options ) = @_;
    $options           ||= {};
	# needs a hoverclass if it is to function! 
	# FIXME probably a bug in scriptaculous!
	$options->{hoverclass} ||= 'hoversmocherpocher';
    $options->{with}   ||= "'id=' + encodeURIComponent(element.id)";
    $options->{onDrop} ||=
      "function(element){" . _remote_function($options) . "}";
    for my $option ( @{$ajax_options} ) {
        delete $options->{$option};
    }
    $options->{accept} = ( "'" . $options->{accept} . "'" )
      if $options->{accept};
    $options->{hoverclass} = ( "'" . $options->{hoverclass} . "'" )
      if $options->{hoverclass};
    my $js_options = _options_for_javascript($options);
    return $self->javascript_tag(
        "Droppables.add( '$element_id', $js_options )");
}

=item $prototype->evaluate_remote_response

Returns 'eval(request.responseText)' which is the Javascript function
that form_remote_tag can call in :complete to evaluate a multiple
update return document using update_element_function calls.

=cut

sub evaluate_remote_response {
    return "eval(request.responseText)";
}

=item $prototype->form_remote_tag(\%options)

Returns a form tag that will submit in the background using XMLHttpRequest,
instead of the regular reloading POST arrangement.

Even though it is using JavaScript to serialize the form elements, the
form submission will work just like a regular submission as viewed by
the receiving side.

The options for specifying the target with C<url> and defining callbacks
are the same as C<link_to_remote>.

=cut

sub form_remote_tag {
    my ( $self, $options ) = @_;
    $options->{form} = 1;
    $options->{html_options} ||= {};
    $options->{html_options}->{action} ||= $options->{url} || '#';
    $options->{html_options}->{method} ||= 'post';
    $options->{html_options}->{onsubmit} =
      _remote_function($options) . '; return false';
    return $self->tag( 'form', $options->{html_options}, 1 );
}

=item $prototype->javascript_tag( $content, \%html_options )

Returns a javascript block with opening tag, content and ending tag.

=cut

sub javascript_tag {
    my ( $self, $content, $html_options ) = @_;
    $html_options ||= {};
    my %html_options = ( type => 'text/javascript', %$html_options );
    my $tag = HTML::Element->new( 'script', %html_options );
    $tag->push_content("\n<!--\n$content\n//-->\n");
    return $tag->as_HTML;
}

=item $prototype->link_to_function( $name, $function, \%html_options )

Returns a link that will trigger a JavaScript function using the onClick
handler and return false after the fact.

Examples:

    $prototype->link_to_function( "Greeting", "alert('Hello world!') )
    $prototype->link_to_function( '<img src="really.png"/>', 'do_delete()' )

=cut

sub link_to_function {
    my ( $self, $name, $function, $html_options ) = @_;
    $html_options ||= {};
    my %html_options =
      ( href => '#', onclick => "$function; return false", %$html_options );
    return $self->content_tag( 'a', $name, \%html_options );
}

=item $prototype->link_to_remote( $content, \%options, \%html_options )

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

You can customize further browser side call logic by passing
in Javascript code snippets via some optional parameters. In
their order of use these are:

C<confirm>: Adds confirmation dialog.

C<condition>:  Perform remote request conditionally by this expression.
Use this to describe browser-side conditions when request should not be
initiated.

C<before>: Called before request is initiated.

C<after>: Called immediately after request was initiated and before C<loading>.

=cut

sub link_to_remote {
    my ( $self, $id, $options, $html_options ) = @_;
    $self->link_to_function( $id, _remote_function($options), $html_options );
}

=item $prototype->observe_field( $id, \%options)

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
    $options ||= {};
    if ( $options->{frequency} ) {
        return $self->_build_observer( 'Form.Element.Observer', $id, $options );
    }
    else {
        return $self->_build_observer( 'Form.Element.EventObserver', $id,
            $options );
    }
}

=item $prototype->observe_form( $id, \%options )

Like C<observe_field>, but operates on an entire form identified by
the DOM ID $id.

Options are the same as C<observe_field>, except the default value of
the C<with> option evaluates to the serialized (request string) value
of the form.

=cut

sub observe_form {
    my ( $self, $id, $options ) = @_;
    $options ||= {};
    if ( $options->{frequency} ) {
        return $self->_build_observer( 'Form.Observer', $id, $options );
    }
    else {
        return $self->_build_observer( 'Form.EventObserver', $id, $options );
    }
}

=item $prototype->periodically_call_remote( \%options )

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
    $options->{html_options} ||= { type => 'text/javascript' };
    return $self->javascript_tag( <<"", $options->{html_options} );
new PeriodicalExecuter( function () { $code }, $frequency );

}

=item $prototype->sortable_element( $element_id, \%options )

Makes the element with the DOM ID specified by +element_id+ sortable
by drag-and-drop and make an Ajax call whenever the sort order has
changed. By default, the action called gets the serialized sortable
element as parameters.

Example:
    $ptototype->sortable_element( 'my_list', { url => 'http://foo.bar/baz' } );

In the example, the action gets a "my_list" array parameter 
containing the values of the ids of elements the sortable consists 
of, in the current order.

You can change the behaviour with various options, see
http://script.aculo.us for more documentation.

=cut

sub sortable_element {
    my ( $self, $element_id, $options ) = @_;
    $options             ||= {};
    $options->{with}     ||= "Sortable.serialize('$element_id')";
    $options->{onUpdate} ||=
      'function () { ' . _remote_function($options) . ' }';
    for my $option ( @{$ajax_options} ) {
        delete $options->{$option};
    }
    my $js_options = _options_for_javascript($options);
    return $self->javascript_tag(
        "Sortable.create( '$element_id', $js_options )");
}

=item $prototype->submit_to_remote( $name, $value, \%options )

Returns a button input tag that will submit a form using XMLHttpRequest
in the background instead of a typical reloading via POST.

C<options> argument is the same as in C<form_remote_tag>

=cut

sub submit_to_remote {
    my ( $self, $name, $value, $options ) = @_;
    $options->{html_options} ||= {};
    $options->{html_options}->{onclick} =
      _remote_function($options) . '; return false';
    $options->{html_options}->{type}  = 'button';
    $options->{html_options}->{name}  = $name;
    $options->{html_options}->{value} = $value;
    return $self->tag( 'input', $options->{html_options} );
}

=item $prototype->tag( $name, \%options, $starttag );

Returns a opening tag.

=cut

sub tag {
    my ( $self, $name, $options, $starttag ) = @_;
    $starttag ||= 0;
    $options  ||= {};
    my $tag = HTML::Element->new( $name, %$options );
    return $tag->starttag if $starttag;
    return $tag->as_XML;
}

=item $prototype->update_element_function( $element_id, \%options, \&code )

Returns a Javascript function (or expression) that'll update a DOM element
according to the options passed.

C<content>: The content to use for updating.
Can be left out if using block, see example.

C<action>: Valid options are C<update> (assumed by default), :empty, :remove

C<position>: If the :action is :update, you can optionally specify one
of the following positions: :before, :top, :bottom, :after.

Example:
    $prototype->javascript_tag( $prototype->update_element_function(
        'products', { position => 'bottom', content => '<p>New product!</p>'
    ) );

This method can also be used in combination with remote method call
where the result is evaluated afterwards to cause multiple updates
on a page.

Example:
     # View
    $prototype->form_remote_tag( {
        url      => { "http://foo.bar/buy" },
        complete => $prototype->evaluate_remote_response
    } );

    # Returning view
    $prototype->update_element_function( 'cart', {
        action   => 'update',
        position => 'bottom', 
        content  => "<p>New Product: $product_name</p>"
    } );
    $prototype->update_element_function( 'status',
        { binding => "You've bought a new product!" } );

=cut

sub update_element_function {
    my ( $self, $element_id, $options, $code ) = @_;
    $options ||= {};
    my $content = $options->{content} || '';
    $content = &$code if $code;
    my $action = $options->{action} || $options->{update};
    my $javascript_function = '';
    if ( $action eq 'update' ) {
        if ( my $position = $options->{position} ) {
            $position            = ucfirst $position;
            $javascript_function =
              "new Insertion.$position( '$element_id', '$content' )";
        }
        else {
            $javascript_function = "\$('$element_id').innerHTML = '$content'";
        }
    }
    elsif ( $action eq 'empty' ) {
        $javascript_function = "\$('#$element_id').innerHTML = ''";
    }
    elsif ( $action eq 'remove' ) {
        $javascript_function = "Element.remove('$element_id')";
    }
    else {
        die "Invalid action, choose one of :update, :remove, :empty";
    }
    $javascript_function .= "\n";
    return $options->{binding}
      ? ( $javascript_function . $options->{binding} )
      : $javascript_function;
}

=item $prototype->visual_effect( $name, $element_id, \%js_options )

Returns a JavaScript snippet to be used on the Ajax callbacks for starting
visual effects.

    $prototype->link_to_remote( 'Reload', {
        update   => 'posts',
        url      => 'http://foo.bar/baz',
        complete => $prototype->visual_effect( 'highlight', 'posts', {
            duration => '0.5'
        } )
    } );

=cut

sub visual_effect {
    my ( $self, $name, $element_id, $js_options ) = @_;
    $js_options ||= {};
    $name = ucfirst $name;
    my $options = _options_for_javascript($js_options);
    return "new Effect.$name( '$element_id', $options );";
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
    my ( $self, $class, $name, $options ) = @_;
    $options->{with} ||= 'value' if $options->{update};
    my $freq = $options->{frequency};
    my $callback = _remote_function($options);
       if ( $freq ) {
          return $self->javascript_tag(
              "new $class( '$name', 
                           $freq, 
                           function( element, value ) { 
                               $callback 
                            } );");
       } else {
          return $self->javascript_tag(
              "new $class( '$name', 
                           function( element, value ) { 
                               $callback 
                            } );");
       }
}

sub _options_for_ajax {
    my $options    = shift;
    my $js_options = _build_callbacks($options);
    $options->{type} ||= "''";
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

sub _options_for_javascript {
    my $options = shift;
    my @options;
    for my $key ( keys %$options ) {
        my $value = $options->{$key};
        push @options, "$key: $value";
    }
    return '{ ' . join( ', ', sort(@options) ) . ' }';
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

=back

=head1 SEE ALSO

L<Catalyst::Plugin::Prototype>, L<Catalyst>.
L<http://prototype.conio.net/>

=head1 AUTHOR

Sebastian Riedel, C<sri@oook.de>
Marcus Ramberg, C<mramberg@cpan.org>

Built around Prototype by Sam Stephenson.
Much code is ported from Ruby on Rails javascript helpers.

=head1 THANK YOU

Drew Taylor, Leon Brocard, Andreas Marienborg

=head1 LICENSE

This library is free software. You can redistribute it and/or modify it under
the same terms as perl itself.

=cut

1;
## Please see file perltidy.ERR
