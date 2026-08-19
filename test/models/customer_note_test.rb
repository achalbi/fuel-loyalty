require "test_helper"

class CustomerNoteTest < ActiveSupport::TestCase
  setup do
    @customer = Customer.create!(name: "Note Nina", phone_number: "9876511001")
    @staff = users(:two)
  end

  test "assigning info_note appends a dated entry instead of overwriting" do
    # Staff feedback item 13: every note is its own entry, so the history of
    # what was said and when survives the next conversation.
    @customer.info_note_author = @staff
    @customer.update!(info_note: "Asked about fleet pricing")
    @customer.update!(info_note: "Called back — wants a quote")

    bodies = @customer.customer_notes.reload.map(&:body)
    assert_equal ["Called back — wants a quote", "Asked about fleet pricing"], bodies
    assert_equal [@staff, @staff], @customer.customer_notes.map(&:author)
  end

  test "reading info_note returns the most recent entry" do
    @customer.update!(info_note: "First")
    @customer.update!(info_note: "Second")

    assert_equal "Second", @customer.reload.info_note
  end

  test "saving without touching the note adds nothing" do
    @customer.update!(info_note: "Only note")

    assert_no_difference -> { @customer.customer_notes.count } do
      @customer.update!(name: "Renamed")
    end
  end

  test "a blank note is ignored" do
    assert_no_difference -> { CustomerNote.count } do
      @customer.update!(info_note: "   ")
    end
  end

  test "an over-long note is a validation error, not a mid-save raise" do
    @customer.info_note = "x" * 2001

    assert_not @customer.save
    assert_includes @customer.errors[:info_note], "is too long (maximum is 2000 characters)"
  end

  test "a note carried over from the old column has no author" do
    note = @customer.customer_notes.create!(body: "Backfilled")

    assert_nil note.author
    assert_equal "Earlier note", note.author_label
  end
end
