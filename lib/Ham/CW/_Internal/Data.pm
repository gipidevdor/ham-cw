package Ham::CW::_Internal::Data;
use 5.020;
use strict;
use warnings;
use Exporter 'import';
use Scalar::Util qw(blessed refaddr);
our @EXPORT_OK = qw(plain_data);

# Only unblessed, acyclic arrays/hashes with scalar leaves are copyable payloads.
# Track ancestors rather than all references: shared children are valid.
sub plain_data {
    my ($value) = @_;
    my @pending = ([$value, 0, 0]);
    my (%active, %checked);
    while (my $item = pop @pending) {
        my ($node, $depth, $leaving) = @{$item};
        next unless ref $node;
        my $address = refaddr($node);
        if ($leaving) {
            delete $active{$address};
            $checked{$address} = $depth;
            next;
        }
        return 0 if blessed($node) || $depth > 64 || $active{$address};

        # Shared subtrees validated at this depth or deeper need no second
        # traversal. A deeper arrival still checks the complete depth limit.
        next if exists($checked{$address}) && $checked{$address} >= $depth;
        my $kind = ref $node;
        return 0 unless $kind eq 'ARRAY' || $kind eq 'HASH';
        $active{$address} = 1;
        push @pending, [$node, $depth, 1];
        push @pending, map { [$_, $depth + 1, 0] } $kind eq 'ARRAY' ? @{$node} : values %{$node};
    }
    return 1;
}
1;
