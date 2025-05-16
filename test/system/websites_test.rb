require "application_system_test_case"

class WebsitesTest < ApplicationSystemTestCase
  setup do
    @website = websites(:one)
  end

  test "visiting the index" do
    visit websites_url
    assert_selector "h1", text: "Websites"
  end

  test "should create website" do
    visit websites_url
    click_on "New website"

    click_on "Create Website"

    assert_text "Website was successfully created"
    click_on "Back"
  end

  test "should update Website" do
    visit website_url(@website)
    click_on "Edit this website", match: :first

    click_on "Update Website"

    assert_text "Website was successfully updated"
    click_on "Back"
  end

  test "should destroy Website" do
    visit website_url(@website)
    click_on "Destroy this website", match: :first

    assert_text "Website was successfully destroyed"
  end
end
