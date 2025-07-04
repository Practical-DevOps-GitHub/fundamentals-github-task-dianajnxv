require 'test/unit'
require_relative '../src/script'

class ScriptTest < Test::Unit::TestCase

  def setup
    url = ENV['URL'].nil? ? '' : ENV["URL"]
    token = ENV['TOKEN'].nil? ? '' : ENV["TOKEN"]
    @secrets_token = ENV['SECRETS_TOKEN']
    @obj = GithubApi.new(url, token)
  end

  def test_health_check
    assert_not_nil(@obj.instance_variable_get('@repo_uri'), 'Url alive')
    assert_not_nil(@obj.instance_variable_get('@token'), 'Token alive')
  end
  
  def test_token_present
    actual = @secrets_token =~ /^ghp_\w{36}$/
    assert_not_nil(actual, "Secret with name 'PAT' with valid personal access token doesn't exist")
  end

  def test_deploy_key_present
    response = @obj.deploy_keys
    assert_not_nil(response, "Access denied")
    deploy_key = response.find {|element| element['title'] == 'DEPLOY_KEY'}
    assert_not_nil(deploy_key, "The deploy key with name 'DEPLOY_KEY' doesn't exist")
  end

  def test_main_present
    actual = @obj.branch_exist?('main')
    assert(actual, 'Branch main is not present')
  end

  def test_main_protected
    actual = @obj.branch_protected?('main')
    assert(actual, 'Branch main is not protected')
  end

  def test_develop_present
    actual = @obj.branch_exist?('develop')
    assert(actual, 'Branch develop is not present')
  end

  def test_develop_protected
    actual = @obj.branch_protected?('develop')
    assert(actual, 'Branch develop is not protected')
  end

  def test_develop_default
    actual = @obj.default_branch
    expected = 'develop'
    assert_equal(expected, actual, 'Default branch isn\'t  develop')
  end

  def test_codeowners_contains_user
    user_name = 'softservedata'
    content = @obj.file_branch('CODEOWNERS', 'main') || @obj.file_branch('.github/CODEOWNERS', 'main') || @obj.file_branch('docs/CODEOWNERS', 'main')
    assert_not_nil(content, 'File CODEOWNERS doesn\'t exist on main branch')
    assert(content.include?(user_name), "User #{user_name} doesn't present in CODEOWNERS")
  end

  def test_codeowners_not_present_develop
    content = @obj.file_branch('CODEOWNERS', 'develop')
    assert_nil(content, 'File CODEOWNERS exist on develop branch')
  end

  def test_deny_merge_main
    classic_rules = @obj.rules_required_pull_request_reviews('main')
    rulesets = @obj.get_branch_ruleset('main')
    rulesets_rules = rulesets&.find { |rule| rule['type'] == 'pull_request' }
    assert_not_nil(classic_rules || rulesets_rules, 'We should not allow merge to main branch without PR')
  end

  def test_deny_merge_develop
    classic_rules = @obj.rules_required_pull_request_reviews('develop')
    rulesets = @obj.get_branch_ruleset('develop')
    rulesets_rules = rulesets&.find { |rule| rule['type'] == 'pull_request' }
    assert_not_nil(classic_rules || rulesets_rules, 'We should not allow merge to develop branch without PR ')
  end

  def test_2_approvals_develop
    classic_required_approving_review_count = @obj.rules_required_pull_request_reviews('develop').nil? || @obj.rules_required_pull_request_reviews('develop')["required_approving_review_count"]
    pull_request_rulesets_rules = @obj.get_branch_ruleset('develop')
    rulesets_required_approving_review_count = pull_request_rulesets_rules&.find { |rule| rule['type'] == 'pull_request' }&.[]('parameters')&.[]('required_approving_review_count')
    expected = 2
    required_approving_review_count = classic_required_approving_review_count == expected || rulesets_required_approving_review_count == expected
    assert_true(required_approving_review_count, 'We should have 2 approvals before merge to develop branch')
  end

  #def test_without_approval_main
   # classic_required_approving_review_count = @obj.rules_required_pull_request_reviews('main').nil? || @obj.rules_required_pull_request_reviews('main')["required_approving_review_count"]
    #pull_request_rulesets_rules = @obj.get_branch_ruleset('main')
    #rulesets_required_approving_review_count = pull_request_rulesets_rules&.find { |rule| rule['type'] == 'pull_request' }&.[]('parameters')&.[]('required_approving_review_count')
    #expected = 0
    #required_approving_review_count = classic_required_approving_review_count == expected || rulesets_required_approving_review_count == expected
    #assert_true(required_approving_review_count, 'We shouldn\'t have any approvals before merge to main branch')
  #end

  def test_approve_from_user
    user_name = 'softservedata'
    classic_require_code_owner_review = @obj.rules_required_pull_request_reviews('main')["require_code_owner_reviews"]
    pull_request_rulesets_rules = @obj.get_branch_ruleset('main')
    rulesets_require_code_owner_review = pull_request_rulesets_rules&.find { |rule| rule['type'] == 'pull_request' }&.[]('parameters')&.[]('require_code_owner_review')
    assert(classic_require_code_owner_review || rulesets_require_code_owner_review, "We should not allow merge to main branch without approve from #{user_name}")
  end

  def test_PR_template_present
    actual = @obj.file_branch('.github/pull_request_template.md', 'main')
    assert_not_nil(actual, 'Pull request template is absent')
  end

end
