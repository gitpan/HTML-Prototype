package HTML::Prototype;

use strict;
use base 'Class::Accessor::Fast';

our $VERSION = '1.22';
use HTML::Prototype::Js;
our $prototype = do { package HTML::Prototype::Js; local $/; <DATA> };
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
This library allows you to do Ajax without writing lots of javascript 
code.

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

=head3 $prototype->link_to_remote( $content, \%options )

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
L<http://prototype.conio.net/>

=head1 AUTHOR

Sebastian Riedel, C<sri@oook.de>
Marcus Ramberg, C<mramberg@cpan.org>

Built around Prototype by Sam Stephenson.
Much code is ported from Ruby on Rails javascript helpers.

=head1 THANK YOU

Drew Taylor, Leon Brocard

=head1 LICENSE

This library is free software. You can redistribute it and/or modify it under
the same terms as perl itself.

=cut

1;
