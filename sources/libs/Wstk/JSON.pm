# ******************************************************************************************
# based on http://www.json.org
# inital version 2.0_2007
#  + added unicode parser: \uXXYY (2016)
#  + added aliases (2020)
# 
# Copyright (C) AlexandrinKS
# https://akscf.me/
# ******************************************************************************************
package Wstk::JSON;
use Log::Log4perl;
use Wstk::Boolean;

# by Jeremy Muhlich <jmuhlich [at] bitflood.org>
my %escapes = ( 
  b    => "\x8",
  t    => "\x9",
  n    => "\xA",
  f    => "\xC",
  r    => "\xD",
#  '/'  => '/',
  '\\' => '\\',
);

sub new ($$;$) {
    my ($class, %args) = @_;
    my %t = (        
         class  	     => __PACKAGE__,
	       logger        => Log::Log4perl::get_logger(__PACKAGE__),
	       use_raw	     => 0,
	       bool_true	   => TRUE,   # wstk::true
	       bool_false	   => FALSE,  # wstk::false
	       auto_bless	   => 0,
         use_aliases   => 0,
         a2c_map       => {},     # aliases map
         c2a_map       => {}      # aliases map
    );
    my $self= {%t, %args};
    bless( $self, $class );
}

sub DESTROY {
    return;
}

# decode
{ 
    my $text;
    my $at;
    my $ch;
    my $len;
    my $unmap; # unmmaping
    my $bare;  # bareKey
    my $apos;  # loosely quoting
    my $pself;

    sub decode {
        my $self = shift;
        $text 	 = shift;
        $at    	 = 0;
        $ch   	 = '';
        $len  	 = length $text;
        $pself	 = $self;
        
        return value();
    }

    sub next_chr {
        return $ch = undef if($at >= $len);
        $ch = substr($text, $at++, 1);
    }

    #------------------------------------------------------------------------------#
    sub value {
      white();
      if(!defined $ch) {
        return;
      }
    	if($ch eq '{') { 
  	    my $o = object(); 
        return $o if(!$pself->{auto_bless} || !$o->{'class'}); 
        my $alias = $o->{'class'};
        if($alias) {
          if($pself->{use_aliases}) {
            my $type = $pself->{a2c_map}->{$alias};
            if($type) { $o->{'class'} = $type; $alias = $type;}
            else { $alias =~ s/\./\:\:/g; }
          } else { $alias =~ s/\./\:\:/g; }
        }  	    
        return bless($o, $alias);
      }
      if($ch eq '[') {
        return array();
      }
      if($ch eq '"' or ($apos and $ch eq "'")) {
        return string();
      }
      if($ch eq '-') {
        return number();
      }
      return $ch =~ /\d/ ? number() : word();
    }

    #------------------------------------------------------------------------------#
    sub string  {
        my ($i,$s,$t,$u);
        $s = '';
        if($ch eq '"' or ($apos and $ch eq "'")) {
            my $boundChar = $ch if ($apos);
            #
            OUTER: while( defined(next_chr()) ) {
                if((!$apos and $ch eq '"') or ($apos and $ch eq $boundChar)) {
                    next_chr();
                    return $s;
                }
                elsif($ch eq '\\') {
                    next_chr();
                    if(exists $escapes{$ch}) { 
                        $s .= $escapes{$ch}; 
		            }
                    elsif($ch eq 'u') {
                        my $u = '';
                        for(1..4) {
                            $ch = next_chr();
                            last OUTER if($ch !~ /[\da-fA-F]/);
                            $u .= $ch;
                        }
                        $s .= chr(hex($u));
                    }
                    else { $s .= $ch; }
                }
                else { $s .= $ch; }
            }
        }
        error("Bad string");
    }

    #------------------------------------------------------------------------------#
    sub number {
        my $n   ="" ;
        my $v	="";
	
        if($ch eq '0') {
            my $peek = substr($text,$at,1);
            my $hex  = $peek =~ /[xX]/;
            if(defined $n and length($n)) {
                $at += length($n) + $hex;
                next_chr;
                return $hex ? hex($n) : oct($n);
            }
        }

        if($ch eq '-')     { $n = '-';  next_chr; }
        while($ch =~ /\d/) { $n .= $ch; next_chr; }

        if($ch eq '.') {
            $n .= '.';
            while(defined(next_chr) and $ch =~ /\d/) {
                $n .= $ch;
            }
        }

        if($ch eq 'e' or $ch eq 'E'){
            $n .= $ch;
            next_chr;
            if(defined($ch) and ($ch eq '+' or $ch eq '-' or $ch =~ /\d/)) {
                $n .= $ch;
            }
            while(defined(next_chr) and $ch =~ /\d/) {
                $n .= $ch;
            }
        }
        $v .= $n;
        return $v;
    }

    #------------------------------------------------------------------------------#
    # whitespace && coments
    sub white {
        while( defined $ch  ) {
            if($ch le ' ') {
                next_chr();
            }
            elsif($ch eq '/')
	    {
                next_chr();
                if($ch eq '/')
		{
                    1 while(defined(next_chr()) and $ch ne "\n" and $ch ne "\r");
                }
                elsif($ch eq '*')
		{
                    next_chr();
                    while(1)
		    {
                        if(defined $ch)
			{
                            if($ch eq '*')
			    {
                                if(defined(next_chr()) and $ch eq '/')
				{
                                    next_chr();
                                    last;
                                }
                            }
                            else { next_chr(); }
                        }
                        else { error("Unterminated comment"); }
                    }
                    next;
                }
                else { error("Syntax error `whitespace` ");  }
            }
            else { last; }
        }
    }

    #------------------------------------------------------------------------------#
    sub object 
    {
        my $o = {};
        my $k;
        if($ch eq '{') {
            next_chr();
            white();
            if($ch eq '}') {
                next_chr();
                return $o;
            }
            while(defined $ch) {
                $k = ($bare and $ch ne '"' and $ch ne "'") ? bareKey() : string();
                white();
                if($ch ne ':') { last; }
                next_chr();
                $o->{$k} = value();
                white();
                if($ch eq '}') {
                    next_chr();
                    return $o;
                }
                elsif($ch ne ',') { last;  }
                next_chr();
                white();
            }
            error("Bad object");
        }
    }

    #------------------------------------------------------------------------------#
    sub array {
        my $a  = [];
        if($ch eq '[') {
            next_chr();
            white();
            if($ch eq ']') {
                next_chr();
                return $a;
            }
            while(defined($ch)) {
                push @$a, value();
                white();
                if($ch eq ']') {
                    next_chr();
                    return $a;
                }
                elsif($ch ne ',') { last; }
                next_chr();
                white();
            }
        }
        error("Bad array");
    }

    #------------------------------------------------------------------------------#
    # bareKEY /  doesn't strictly follow Standard ECMA-262 3rd Edition
    sub bareKey { 
        my $key;
        while($ch =~ /[^\x00-\x23\x25-\x2F\x3A-\x40\x5B-\x5E\x60\x7B-\x7F]/) {
            $key .= $ch;
            next_chr();
        }
        return $key;
    }

    #------------------------------------------------------------------------------#
    # WORD (null,true,false)
    sub word {
        my $word =  substr($text,$at-1,4);
        if($word eq 'true') {		         # $self->{bool_true}
            $at += 3;
            next_chr;
	        return $pself->{bool_true};
        } elsif($word eq 'null') {			# undef
            $at += 3;
            next_chr;
	        return undef;
        } elsif($word eq 'fals') {			# $self->{bool_false}
            $at += 3;
            if(substr($text,$at,1) eq 'e') {
                $at++;
                next_chr;
		       return $pself->{bool_false};
            }
        }
        error("Syntax error `word`");
    }

    #------------------------------------------------------------------------------#
    sub error {
        my $error  = shift;
        my $str = substr($text, $at);
        unless (length $str) { $str = '(end of string)'; }
        die "$error, at character offset $at ($str)";
    }
} #end_decode

sub encode
{
    my $self    = shift;
    my $obj_ref = shift;

    #------------------------------------------------------------------------------#
    if(!defined($obj_ref)) {
        return 'null';
    }

    #------------------------------------------------------------------------------#
    if(ref($obj_ref)) {
      if(ref($obj_ref) eq 'ARRAY') {		# ARRAY
        my $out = '['; my $ntg=0;
        foreach my $el (@{$obj_ref}) {
          unless($ntg){$ntg=1;} else {$out .= ',';}
              my $tmp = encode($self,$el);
              $out .= $tmp ;
        }
        return $out . ']'; 
      }
      elsif(ref($obj_ref) eq 'HASH') {	# HASH
          my $out = '{'; my $ntg = 0;
          foreach my $key (keys(%{$obj_ref})) {
            next if(!defined($key) || !length($key));
            unless($ntg){ $ntg=1; }
            else { $out .= ','; }
            my $tmp = encode($self,$obj_ref->{$key});
            $out .= '"'. $key .'":'. $tmp;
          }
          return $out .'}';
      }
      elsif(ref($obj_ref) eq 'SCALAR') {	# SCALAR
        $tmp=encode($self,$$obj_ref);
        return $tmp;
      }
      elsif(ref($obj_ref) eq 'REF') {		# REF
        $tmp=encode(\$obj_ref);
        return $tmp;
      }
      elsif(ref($obj_ref) eq 'CODE') {	# CODE
        return "null";
      }
      elsif(ref($obj_ref) eq 'GLOB') {	# GLOB
        return "null";
      }
      elsif(ref($obj_ref) eq 'LVALUE') {	# LVALUE
        return "null";
      } 
      else { # object
        my $out = '{'; my $ntg=0; $@='';
        eval {
          foreach my $key (keys(%{$obj_ref})) {
            next if(!defined($key) || !length($key));
            unless($ntg){$ntg=1;} else {$out .= ',';}
            if($key eq 'class') {
              my $type = $obj_ref->{$key};
              if($type && $self->{use_aliases}) {
                my $alias = $self->{c2a_map}->{$type};
                $out .= '"'. $key .'":"'. ($alias ? $alias : $type).'"';
              } else {
                $out .= '"'. $key .'":'. encode($self, $type);
              }              
            } else {
              $out .= '"'. $key .'":'. encode($self, $obj_ref->{$key});
            }
        	}
        	$out .= '}';
        };
        return 'null' if($@);
  	    return $out;
      }
    }
    else {
        if($obj_ref=~/^([+-]?)(?=\d|\.\d)\d*(\.\d*)?([Ee]([+-]?\d+))?$/) { # digit
            return "\"".$obj_ref."\"";
        }
        elsif(is_bool($self,$obj_ref)) {	# boolean
          return 'true'  if($self->{bool_true}  eq lc($obj_ref));
          return 'false' if($self->{bool_false} eq lc($obj_ref));
          return '"'.$obj_ref.'"'; # as string
        }
        else { # any data as string
          my $out;
          my @str=split(//,$obj_ref);
          for(my $cid,my $i=0; $i<scalar(@str); $i++ ) {
          $cid = ord($str[$i]);

    #---------------------------------------------------------------------------------#
    # escape x22(") \b \t \n \f \r    ( deleted: x2f(/), x5c(\) )
		if($cid == 0x22 ) { $out .= "\\".$str[$i]; next; }
		if($cid == 0x08 ) { $out .= "\\b"; next; }
		if($cid == 0x09 ) { $out .= "\\t"; next; }
		if($cid == 0x0a ) { $out .= '\\n'; next; } 
		if($cid == 0x0c ) { $out .= '\\f'; next; }
		if($cid == 0x0d ) { $out .= '\\r'; next; }

		#---------------------------------------------------------------------------------#
		# copy ASCII x20 - x7f
		if($cid >= 0x20 && $cid <= 0x7f) { $out .= $str[$i]; next; }

	  #---------------------------------------------------------------------------------#
		unless($self->{use_raw}) {
            # chars U-00000080 - U-000007FF, mask 110XXXXX
	    	    if(($cid & 0xE0) == 0xC0) {
            		my $char=pack('C*',$cid,ord($str[++$i])); 
            	        my $utf16=utf8_to_utf16($self,$char);
                	$out .= sprintf('\u%04s', unpack("H*",$utf16));
			next;
		    }
		    # chars U-00000800 - U-0000FFFF, mask 1110XXXX
		    if(($cid & 0xF0) == 0xE0) {
            	        my $char = pack('C*', $cid, ord($str[++$i]), ord($str[++$i])); 
                	my $utf16 = utf8_to_utf16($self,$char);
                	$out .= sprintf('\u%04s', unpack("H*",$utf16));
                	next;
		    }
		    # chars U-00010000 - U-001FFFFF, mask 11110XXX
		    if(($cid & 0xF8) == 0xF0) {
                	my $char = pack('C*', $cid, ord($str[++$i]), ord($str[++$i]), ord($str[++$i])); 
            	        my $utf16 = utf8_to_utf16($self,$char);
                	$out .= sprintf('\u%04s', unpack("H*",$utf16));
                	next;
		    }
		    # chars U-00200000 - U-03FFFFFF, mask 111110XX
            	    if(($cid & 0xFC) == 0xF8) {            
            		my $char = pack('C*', $cid, ord($str[++$i]), ord($str[++$i]), ord($str[++$i]), ord($str[++$i])); 
                	my $utf16 = utf8_to_utf16($self,$char);
                	$out .= sprintf('\u%04s', unpack("H*",$utf16));
                	next;
		    }
		    # chars U-04000000 - U-7FFFFFFF, mask 1111110X
        if(($cid & 0xFE) == 0xFC) {
          my $char = pack('C*', $cid, ord($str[++$i]), ord($str[++$i]), ord($str[++$i]), ord($str[++$i]), ord($str[++$i]));
          my $utf16 = utf8_to_utf16($self,$char);
          $out .= sprintf('\u%04s', bin2hex($utf16));
		    }
		}
		$out .= $str[$i];
	    }
	    return '"'.$out.'"';
        }
    }
    return 'null';
}

#----------------------------------------------------------------------------------#
sub alias_register {
  my($self, $alias, $type) = @_;  
  if(!defined($alias) || !defined($type)) {
      die("Invalid arguments: alias or type");
  }
  unless($self->{use_aliases}) {
    return 0;
  }
  my $amap = $self->{a2c_map};
  my $cmap = $self->{c2a_map};
  if(exists $amap->{$alias}) {
    die("Alias alias already exists: ".$alias);
  }  
  $amap->{$alias} = $type;
  $cmap->{$type} = $alias;
  return 1;
}

sub alias_unregister {
  my ($self, $alias) = @_;  
  if(!defined($alias)) {
      die("Invalid argument: alias");
  }
  unless($self->{use_aliases}) {
    return 0;
  }
  my $amap = $self->{a2c_map};
  my $cmap = $self->{c2a_map};  
  if(exists $amap->{$alias}) {
    my $type = $amap->{$alias};
    delete($amap->{$alias});
    if(defined $type) {
      delete($cmap->{$type});
    }    
  }
  return 1;  
}

sub alias_lookupa {
  my ($self, $type_name) = @_;
  
  unless($self->{use_aliases}) {
    return undef;
  }
  my $cmap = $self->{c2a_map};
  return $cmap->{$type_name};
}

sub alias_lookupc {
  my ($self, $alias_name) = @_;
  unless($self->{use_aliases}) {
    return undef;
  }
  my $amap = $self->{a2c_map};
  return $amap->{$alias_name};  
}

#----------------------------------------------------------------------------------#
# UTF8 to UTF16
sub utf8_to_utf16 {
  my $self = shift;
  my $utf8 = shift;

  if(length($utf8)==1) {
    return $utf8;
  } elsif(length($utf8)==2) {
    my @buff=unpack("aa",$utf8);
    return (chr(0x07 & (ord($buff[0]) >> 2)) . chr((0xC0 & (ord($buff[0])<<6)) | (0x3F & ord($buff[1]))));
  } elsif(length($utf8)==3) {
    my @buff=unpack("aaa",$utf8);
    return chr((0xF0 & (ord($buff[0]) << 4)) | (0x0F & (ord($buff[1]) >> 2))) . chr((0xC0 & (ord($buff[1])<<6)) | (0x7F & ord($buff[2])));
  } 
  return '';
}

#----------------------------------------------------------------------------------#
# UTF16 to UTF8
sub utf16_to_utf8 {
    my $self  = shift;
    my $utf16 = shift;

    my @buff=unpack("aa",$utf16);
    my $pref= ( ord($buff[0])<<8 ) | ord($buff[1]);

    if(($pref & 0x7F) == $pref) {
      return chr($pref & 0x7F);
    } elsif(($pref & 0x7FF) == $pref) {
      return chr(0xC0 | (($pref >> 6) & 0x1F)) . chr(0x80 | ($pref & 0x3F));
    } elsif(($pref & 0xFFFF) == $pref) {
      return chr(0xE0 | (($pref >> 12) & 0x0F)) . chr(0x80 | (($pref >> 6) & 0x3F)) . chr(0x80 | ($pref & 0x3F));
    }
    return '';
}

#----------------------------------------------------------------------------------#
# set/get bool true
sub bool_true {
    my $self = shift;
    $self->{bool_true}=lc(shift) if(@_);
    return $self->{bool_true};
}

#----------------------------------------------------------------------------------#
# set/get bool false
sub bool_false {
    my $self = shift;
    $self->{bool_false}=lc(shift) if(@_);
    return $self->{bool_false};
}

#----------------------------------------------------------------------------------#
# ret 1 is bool
sub is_bool {
    my $self = shift;
    my $val = lc(shift);
    return 1 if(($val eq $self->{bool_true}) || ($val eq $self->{bool_false}));
    return 0;
}

#----------------------------------------------------------------------------------#
sub auto_bless {
    my $self = shift;
    $self->{auto_bless}=shift if(@_);
    return $self->{auto_bless};
}


#----------------------------------------------------------------------------------#
# use raw
sub use_raw {
    my $self = shift;
    $self->{use_raw}=shift if (@_);
    return $self->{use_raw};
}

1;
