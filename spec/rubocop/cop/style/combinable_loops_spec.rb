# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Style::CombinableLoops, :config do
  context 'when looping method' do
    it 'registers an offense when looping over the same data as previous loop' do
      expect_offense(<<~RUBY)
        items.each { |item| do_something(item) }
        items.each { |item| do_something_else(item, arg) }
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Combine this loop with the previous loop.

        items.each_with_index { |item| do_something(item) }
        items.each_with_index { |item| do_something_else(item, arg) }
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Combine this loop with the previous loop.

        items.reverse_each { |item| do_something(item) }
        items.reverse_each { |item| do_something_else(item, arg) }
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Combine this loop with the previous loop.
      RUBY

      expect_correction(<<~RUBY)
        items.each { |item| do_something(item)
        do_something_else(item, arg) }

        items.each_with_index { |item| do_something(item)
        do_something_else(item, arg) }

        items.reverse_each { |item| do_something(item)
        do_something_else(item, arg) }
      RUBY
    end

    it 'registers an offense when looping over the same data for the second consecutive time' do
      expect_offense(<<~RUBY)
        items.each do |item| foo(item) end
        items.each { |item| bar(item) }
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Combine this loop with the previous loop.
        do_something
      RUBY

      expect_correction(<<~RUBY)
        items.each do |item| foo(item)
        bar(item)  end
        do_something
      RUBY
    end

    it 'registers an offense when looping over the same data for the third consecutive time' do
      expect_offense(<<~RUBY)
        items.each { |item| foo(item) }
        items.each { |item| bar(item) }
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Combine this loop with the previous loop.
        items.each { |item| baz(item) }
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Combine this loop with the previous loop.
      RUBY

      expect_correction(<<~RUBY)
        items.each { |item| foo(item)
        bar(item)
        baz(item) }
      RUBY
    end

    it 'registers an offense and does not correct when looping over the same data with different block variable names' do
      expect_offense(<<~RUBY)
        items.each { |item| foo(item) }
        items.each { |x| bar(x) }
        ^^^^^^^^^^^^^^^^^^^^^^^^^ Combine this loop with the previous loop.
      RUBY

      expect_no_corrections
    end

    it 'registers an offense when looping over the same data for the third consecutive time with numbered blocks' do
      expect_offense(<<~RUBY)
        items.each { foo(_1) }
        items.each { bar(_1) }
        ^^^^^^^^^^^^^^^^^^^^^^ Combine this loop with the previous loop.
        items.each { baz(_1) }
        ^^^^^^^^^^^^^^^^^^^^^^ Combine this loop with the previous loop.
      RUBY

      expect_correction(<<~RUBY)
        items.each { foo(_1)
        bar(_1)
        baz(_1) }
      RUBY
    end

    it 'registers an offense when looping over the same data for the third consecutive time with `it` blocks', :ruby34 do
      expect_offense(<<~RUBY)
        items.each { foo(it) }
        items.each { bar(it) }
        ^^^^^^^^^^^^^^^^^^^^^^ Combine this loop with the previous loop.
        items.each { baz(it) }
        ^^^^^^^^^^^^^^^^^^^^^^ Combine this loop with the previous loop.
      RUBY

      expect_correction(<<~RUBY)
        items.each { foo(it)
        bar(it)
        baz(it) }
      RUBY
    end

    it 'registers an offense when looping over the same data as previous loop in `do`...`end` and `{`...`}` blocks' do
      expect_offense(<<~RUBY)
        items.each do |item| do_something(item) end
        items.each { |item| do_something_else item, arg}
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Combine this loop with the previous loop.
      RUBY

      expect_correction(<<~RUBY)
        items.each do |item| do_something(item)
        do_something_else item, arg end
      RUBY
    end

    it 'registers an offense when looping over the same data as previous loop in `{`...`}` and `do`...`end` blocks' do
      expect_offense(<<~RUBY)
        items.each { |item| do_something(item) }
        items.each do |item| do_something_else(item, arg) end
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Combine this loop with the previous loop.
      RUBY

      expect_correction(<<~RUBY)
        items.each { |item| do_something(item)
        do_something_else(item, arg) }
      RUBY
    end

    context 'Ruby 2.7' do
      it 'registers an offense when looping over the same data as previous loop in numblocks' do
        expect_offense(<<~RUBY)
          items.each { do_something(_1) }
          items.each { do_something_else(_1, arg) }
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Combine this loop with the previous loop.

          items.each_with_index { do_something(_1) }
          items.each_with_index { do_something_else(_1, arg) }
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Combine this loop with the previous loop.

          items.reverse_each { do_something(_1) }
          items.reverse_each { do_something_else(_1, arg) }
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Combine this loop with the previous loop.
        RUBY

        expect_correction(<<~RUBY)
          items.each { do_something(_1)
          do_something_else(_1, arg) }

          items.each_with_index { do_something(_1)
          do_something_else(_1, arg) }

          items.reverse_each { do_something(_1)
          do_something_else(_1, arg) }
        RUBY
      end
    end

    it 'does not register an offense when the same loops are interleaved with some code' do
      expect_no_offenses(<<~RUBY)
        items.each { |item| do_something(item) }

        some_code

        items.each { |item| do_something_else(item, arg) }
      RUBY
    end

    it 'does not register an offense when the same loop method is used over different collections' do
      expect_no_offenses(<<~RUBY)
        items.each { |item| do_something(item) }
        bars.each { |bar| do_something(bar) }
      RUBY
    end

    it 'does not register an offense when different loop methods are used over the same collection' do
      expect_no_offenses(<<~RUBY)
        items.reverse_each { |item| do_something(item) }
        items.each { |item| do_something(item) }
      RUBY
    end

    it 'does not register an offense when each branch contains the same single loop over the same collection' do
      expect_no_offenses(<<~RUBY)
        if condition
          items.each { |item| do_something(item) }
        else
          items.each { |item| do_something_else(item, arg) }
        end
      RUBY
    end

    it 'does not register an offense for when the same method with different arguments' do
      expect_no_offenses(<<~RUBY)
        each_slice(2) { |slice| do_something(slice) }
        each_slice(3) { |slice| do_something(slice) }
      RUBY
    end

    it 'does not register an offense for when the same method with different arguments and safe navigation' do
      expect_no_offenses(<<~RUBY)
        foo(:bar)&.each { |item| do_something(item) }
        foo(:baz)&.each { |item| do_something(item) }
      RUBY
    end
  end

  context 'when for loop' do
    it 'registers an offense when looping over the same data as previous loop' do
      expect_offense(<<~RUBY)
        for item in items do do_something(item) end
        for item in items do do_something_else(item, arg) end
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Combine this loop with the previous loop.
      RUBY

      expect_correction(<<~RUBY)
        for item in items do do_something(item)
        do_something_else(item, arg) end
      RUBY
    end

    it 'does not register an offense when the same loops are interleaved with some code' do
      expect_no_offenses(<<~RUBY)
        for item in items do do_something(item) end

        some_code

        for item in items do do_something_else(item, arg) end
      RUBY
    end

    it 'does not register an offense when the same loop method is used over different collections' do
      expect_no_offenses(<<~RUBY)
        for item in items do do_something(item) end
        for foo in foos do do_something(foo) end
      RUBY
    end

    it 'does not register an offense when each branch contains the same single loop over the same collection' do
      expect_no_offenses(<<~RUBY)
        if condition
          for item in items do do_something(item) end
        else
          for item in items do do_something_else(item, arg) end
        end
      RUBY
    end

    it 'does not register an offense when one of the loops is empty' do
      expect_no_offenses(<<~RUBY)
        items.each {}
        items.each {}
      RUBY
    end
  end
end
