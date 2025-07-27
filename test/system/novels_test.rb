require "application_system_test_case"

class NovelsTest < ApplicationSystemTestCase
  setup do
    @novel = novels(:one)
  end

  test "visiting the index" do
    visit novels_url
    assert_selector "h1", text: "Novels"
  end

  test "should create novel" do
    visit novels_url
    click_on "New novel"

    click_on "Create Novel"

    assert_text "Novel was successfully created"
    click_on "Back"
  end

  test "should update Novel" do
    visit novel_url(@novel)
    click_on "Edit this novel", match: :first

    click_on "Update Novel"

    assert_text "Novel was successfully updated"
    click_on "Back"
  end

  test "should destroy Novel" do
    visit novel_url(@novel)
    click_on "Destroy this novel", match: :first

    assert_text "Novel was successfully destroyed"
  end
end
