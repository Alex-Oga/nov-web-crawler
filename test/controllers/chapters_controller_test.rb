require "test_helper"

class ChaptersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
    @novel = novels(:one)
    @chapter = chapters(:one)
  end

  test "should get new" do
    get new_novel_chapter_url(@novel)
    assert_response :success
  end

  test "should create chapter" do
    assert_difference("Chapter.count") do
      post novel_chapters_url(@novel), params: { chapter: { name: "New Chapter", link: "https://example.com/new" } }
    end

    assert_redirected_to chapter_url(Chapter.last)
  end

  test "should show chapter" do
    get chapter_url(@chapter)
    assert_response :success
  end

  test "should get edit" do
    get edit_chapter_url(@chapter)
    assert_response :success
  end

  test "should update chapter" do
    patch chapter_url(@chapter), params: { chapter: { name: "Updated Chapter" } }
    assert_redirected_to chapter_url(@chapter)
  end

  test "should destroy chapter" do
    novel = @chapter.novel
    assert_difference("Chapter.count", -1) do
      delete chapter_url(@chapter)
    end

    assert_redirected_to novel_url(novel)
  end
end
