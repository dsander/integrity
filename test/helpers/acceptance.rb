$LOAD_PATH.unshift(File.dirname(__FILE__) + "/../../vendor/webrat/lib")

require File.dirname(__FILE__) + "/../helpers"

gem "foca-storyteller" if respond_to?(:gem)

require "storyteller"
require "webrat"
require "rack/test"
require "bob/test"

module AcceptanceHelper
  include Bob::Test

  def git_repo(name)
    GitRepo.new(name).tap(&:create)
  end

  def login_as(user, password)
    def AcceptanceHelper.logged_in; true; end
    basic_authorize user, password
    Integrity::App.before { login_required if AcceptanceHelper.logged_in }
  end

  def log_out
    def AcceptanceHelper.logged_in; false; end
    rack_test_session.header("HTTP_AUTHORIZATION", nil)
    @_webrat_session = Webrat::Session.new(Webrat::RackSession.new(self))
  end
end

class Test::Unit::AcceptanceTestCase < Test::Unit::TestCase
  include FileUtils
  include AcceptanceHelper
  include Test::Storyteller

  include Rack::Test::Methods
  include Webrat::Methods
  include Webrat::Matchers
  include Webrat::HaveTagMatcher

  Webrat::Methods.delegate_to_session :response_code

  def app
    Rack::Builder.new {
      map "/github" do
        use Bobette::GitHub do
          ! Integrity.config[:build_all_commits]
        end

        run Bobette.new(Integrity::Project)
      end

      map "/" do
        use Rack::Lint
        run Integrity::App
      end
    }
  end

  before(:all) do
    Integrity::App.set(:environment, :test)

    Webrat.configure { |c| c.mode = :rack }
  end

  before(:each) do
    Bob.directory = File.expand_path(File.dirname(__FILE__) + "/../tmp")
    Bob.engine    = Bob::Engine::Foreground
    Bob.logger    = Logger.new("/dev/null")

    Integrity.config = {
      :export_directory => Bob.directory,
      :base_uri         => "http://www.example.com",
      :use_basic_auth   => true,
      :admin_username   => "admin",
      :admin_password   => "test",
      :hash_admin_password => false
    }

    log_out
  end

  after(:each) do
    rm_r(Bob.directory) if File.directory?(Bob.directory)
  end
end
