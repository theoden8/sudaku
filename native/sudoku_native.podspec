Pod::Spec.new do |s|
  s.name             = 'sudoku_native'
  s.version          = '1.0.0'
  s.summary          = 'Native sudoku solver and generator'
  s.description      = 'Algorithm X based sudoku solver with puzzle generation and difficulty estimation'
  s.homepage         = 'https://gitea.com/theoden8/sudaku'
  s.license          = { :type => 'Apache-2.0' }
  s.author           = { 'theoden8' => 'theoden8@example.com' }
  s.source           = { :path => '.' }

  s.ios.deployment_target = '12.0'
  s.osx.deployment_target = '10.14'

  s.source_files = 'sudoku_native.c'
  s.public_header_files = ''

  s.compiler_flags = '-O3 -fvisibility=default'
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'OTHER_LDFLAGS' => '-lm'
  }
end
