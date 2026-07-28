export LANG=en_US.UTF-8                                                                                        
export LC_CTYPE=en_US.UTF-8

eval "$(perl -I"$HOME/perl5/lib/perl5" -Mlocal::lib)"
export PATH="$(ruby -e 'print Gem.user_dir')/bin:$PATH"
