# Pidgin

[![Gem Version](https://img.shields.io/gem/v/pidgin.svg)](https://rubygems.org/gems/pidgin)
[![Build Status](https://img.shields.io/travis/mtwilliams/pidgin/master.svg)](https://travis-ci.org/mtwilliams/pidgin)
[![Code Climate](https://img.shields.io/codeclimate/github/mtwilliams/pidgin.svg)](https://codeclimate.com/github/mtwilliams/pidgin)
[![Dependency Status](https://img.shields.io/gemnasium/mtwilliams/pidgin.svg)](https://gemnasium.com/mtwilliams/pidgin)

Pidgin is a framework for building domain-specific languages quickly and easily. It was cobbled together for [Ryb](https://github.com/mtwilliams/ryb), a project file generator similar to Premake.

It's straight-forward to use. You define your domain-specific language, composed of objects and properties and so forth:

```Ruby
module Ryb
  module DomainSpecificLanguage
    include Pidgin::DomainSpecificLanguage
    collection :project, Ryb::Project
  end

  class Project
    include Pidgin::Object
    property :name, String, :inline => true
    collection :library, Ryb::Library, :plural => :libraries
  end

  class Library
    include Pidgin::Object
    property :name, String, :inline => true
    enum :linkage, [:static, :dynamic], :default => :static
    flag :gen_debug_symbols
    # ...
  end
end
```

Then you use it by calling `Pidgin::DomainSpecificLanguage.eval`, in this case through `Ryb::DomainSpecificLanguage`:

```Ruby
rybfile = Ryb::DomainSpecificLanguage.eval(File.read("Rybfile"))
```

Then use your object hierarchy how you see fit:

```Ruby
rybfile[:projects].each do |project|
  Ryb::XCode4.gen_project_files_for project
end
```

---

Pidgin was written quick 'n' dirty, as a result it has some warts:

  1. It doesn't handle errors well.
  2. It doesn't validate it's assumptions.
  3. It doesn't let you specify custom validation logic.
  4. It doesn't generate DSLs with the best possible syntax.
  5. It has duplicated code that is quite complex in some places.
  6. It has no automated testing suite.
  7. There's not documentation.

I'll eventually loop-back and fix these, but that may be a while. If you want to see Pidgin become something more you'll have to contribute.
