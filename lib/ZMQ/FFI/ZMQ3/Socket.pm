package ZMQ::FFI::ZMQ3::Socket;

use Moo;
use namespace::autoclean;

use FFI::Raw;

extends q(ZMQ::FFI::SocketBase);

with q(ZMQ::FFI::SocketRole);

has zmq3_ffi => (
    is      => 'ro',
    lazy    => 1,
    builder => '_init_zmq3_ffi',
);

sub send {
    my ($self, $msg, $flags) = @_;

    $flags //= 0;

    $self->check_error(
        'zmq_send',
        $self->zmq3_ffi->{zmq_send}->(
            $self->_socket, $msg, length($msg), $flags
        )
    );
}

sub recv {
    my ($self, $flags) = @_;

    $flags //= 0;

    my $ffi = $self->ffi;

    my $msg_ptr = FFI::Raw::memptr(40); # large enough to hold zmq_msg_t

    $self->check_error(
        'zmq_msg_init',
        $ffi->{zmq_msg_init}->($msg_ptr)
    );

    my $msg_size =
        $self->zmq3_ffi->{zmq_msg_recv}->($msg_ptr, $self->_socket, $flags);

    $self->check_error('zmq_msg_recv', $msg_size);

    my $data_ptr    = $ffi->{zmq_msg_data}->($msg_ptr);
    my $content_ptr = FFI::Raw::memptr($msg_size);

    $ffi->{memcpy}->($content_ptr, $data_ptr, $msg_size);
    $ffi->{zmq_msg_close}->($msg_ptr);

    return $content_ptr->tostr($msg_size);
}

sub _init_zmq3_ffi {
    my $self = shift;

    my $ffi    = {};
    my $soname = $self->soname;

    $ffi->{zmq_send} = FFI::Raw->new(
        $soname => 'zmq_send',
        FFI::Raw::int, # retval
        FFI::Raw::ptr, # socket
        FFI::Raw::str, # message
        FFI::Raw::int, # length
        FFI::Raw::int  # flags
    );

    $ffi->{zmq_msg_recv} = FFI::Raw->new(
        $soname => 'zmq_msg_recv',
        FFI::Raw::int, # retval
        FFI::Raw::ptr, # msg ptr
        FFI::Raw::ptr, # socket
        FFI::Raw::int  # flags
    );

    return $ffi;
}

__PACKAGE__->meta->make_immutable();

