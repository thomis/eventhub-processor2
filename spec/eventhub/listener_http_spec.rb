require "spec_helper"
require "uri"
require "net/http"
require "json"

RSpec.describe EventHub::ActorListenerHttp do
  before(:all) do
    Support.ensure_rabbitmq_is_available
  end

  before(:each) do
    EventHub::Configuration.reset
    EventHub::Configuration.name = "processor2"
    EventHub::Configuration.load!
  end

  describe "heartbeat endpoint" do
    let(:listener) {
      EventHub::ActorListenerHttp.new(port: 8081)
    }

    it "gives a valid actor" do
      expect(listener).not_to eq(nil)
    end

    it "succeeds to call rest endpoint" do
      sleep 0.2
      uri = URI("http://localhost:8081/svc/processor2/heartbeat")
      res = Net::HTTP.get_response(uri)

      expect(res.is_a?(Net::HTTPSuccess)).to eq(true)
      expect(res["Content-Type"]).to eq("application/json")

      data = JSON.parse(res.body)
      expect(data).to have_key("version")
      expect(data).to have_key("pid")
      expect(data).to have_key("environment")
      expect(data).to have_key("heartbeat")
      expect(data["heartbeat"]).to have_key("started")
      expect(data["heartbeat"]).to have_key("uptime_in_ms")
      expect(data["heartbeat"]).to have_key("host")
      expect(data["heartbeat"]).to have_key("messages")
    end

    it "fails with not found" do
      sleep 0.1
      uri = URI("http://localhost:8081/unknown")
      res = Net::HTTP.post(uri, nil)

      expect(res.is_a?(Net::HTTPNotFound)).to eq(true)
      expect(res.body).to match(/Not Found/)
    end

    it "fails with method not allowed" do
      sleep 0.1
      uri = URI("http://localhost:8081/svc/processor2/heartbeat")
      res = Net::HTTP.post(uri, nil)

      expect(res.is_a?(Net::HTTPMethodNotAllowed)).to eq(true)
      expect(res.body).to eq("Method Not Allowed")
    end
  end

  describe "version endpoint" do
    context "with version method defined in processor" do
      let(:processor_with_version) {
        Class.new do
          def version
            "1.2.3"
          end
        end.new
      }

      context "with custom base path" do
        it "returns version as JSON at custom path" do
          EventHub::ActorListenerHttp.new(
            port: 8082,
            processor: processor_with_version,
            base_path: "/custom"
          )
          sleep 0.2
          uri = URI("http://localhost:8082/custom/version")
          res = Net::HTTP.get_response(uri)

          expect(res.is_a?(Net::HTTPSuccess)).to eq(true)
          expect(res["Content-Type"]).to eq("application/json")
          body = JSON.parse(res.body)
          expect(body["version"]).to eq("1.2.3")
        end
      end

      context "with default base path" do
        it "returns version as JSON at default path" do
          EventHub::ActorListenerHttp.new(
            port: 8083,
            processor: processor_with_version
          )
          sleep 0.2
          uri = URI("http://localhost:8083/svc/processor2/version")
          res = Net::HTTP.get_response(uri)

          expect(res.is_a?(Net::HTTPSuccess)).to eq(true)
          expect(res["Content-Type"]).to eq("application/json")
          body = JSON.parse(res.body)
          expect(body["version"]).to eq("1.2.3")
        end
      end
    end

    context "without version method defined in processor" do
      let(:processor_without_version) {
        Class.new.new
      }

      context "with custom base path" do
        it "returns default version as JSON" do
          EventHub::ActorListenerHttp.new(
            port: 8084,
            processor: processor_without_version,
            base_path: "/custom"
          )
          sleep 0.2
          uri = URI("http://localhost:8084/custom/version")
          res = Net::HTTP.get_response(uri)

          expect(res.is_a?(Net::HTTPSuccess)).to eq(true)
          expect(res["Content-Type"]).to eq("application/json")
          body = JSON.parse(res.body)
          expect(body["version"]).to eq("?.?.?")
        end
      end

      context "with default base path" do
        it "returns default version as JSON at default path" do
          EventHub::ActorListenerHttp.new(
            port: 8085,
            processor: processor_without_version
          )
          sleep 0.2
          uri = URI("http://localhost:8085/svc/processor2/version")
          res = Net::HTTP.get_response(uri)

          expect(res.is_a?(Net::HTTPSuccess)).to eq(true)
          expect(res["Content-Type"]).to eq("application/json")
          body = JSON.parse(res.body)
          expect(body["version"]).to eq("?.?.?")
        end
      end
    end

    context "without processor" do
      it "returns default version as JSON" do
        EventHub::ActorListenerHttp.new(
          port: 8086,
          base_path: "/api"
        )
        sleep 0.2
        uri = URI("http://localhost:8086/api/version")
        res = Net::HTTP.get_response(uri)

        expect(res.is_a?(Net::HTTPSuccess)).to eq(true)
        body = JSON.parse(res.body)
        expect(body["version"]).to eq("?.?.?")
      end
    end

    it "fails with method not allowed for POST" do
      EventHub::ActorListenerHttp.new(
        port: 8088,
        base_path: "/api"
      )
      sleep 0.2
      uri = URI("http://localhost:8088/api/version")
      res = Net::HTTP.post(uri, nil)

      expect(res.is_a?(Net::HTTPMethodNotAllowed)).to eq(true)
      expect(res.body).to eq("Method Not Allowed")
    end
  end

  describe "docs endpoint" do
    it "returns HTML with README content" do
      EventHub::ActorListenerHttp.new(
        port: 8089,
        base_path: "/api"
      )
      sleep 0.2
      uri = URI("http://localhost:8089/api/docs")
      res = Net::HTTP.get_response(uri)

      expect(res.is_a?(Net::HTTPSuccess)).to eq(true)
      expect(res["Content-Type"]).to include("text/html")
      expect(res.body).to include("<!DOCTYPE html>")
      expect(res.body).to include("EventHub::Processor2")
    end

    it "redirects base path to docs" do
      EventHub::ActorListenerHttp.new(
        port: 8090,
        base_path: "/api"
      )
      sleep 0.2
      uri = URI("http://localhost:8090/api")
      res = Net::HTTP.get_response(uri)

      expect(res.is_a?(Net::HTTPRedirection)).to eq(true)
      expect(res["Location"]).to end_with("/api/docs")
    end

    it "redirects base path with trailing slash to docs" do
      EventHub::ActorListenerHttp.new(
        port: 8091,
        base_path: "/api"
      )
      sleep 0.2
      uri = URI("http://localhost:8091/api/")
      res = Net::HTTP.get_response(uri)

      expect(res.is_a?(Net::HTTPRedirection)).to eq(true)
      expect(res["Location"]).to end_with("/api/docs")
    end

    context "with processor that has version and company_name" do
      let(:processor_with_info) {
        Class.new do
          def version
            "3.0.0"
          end

          def company_name
            "Test Corp"
          end
        end.new
      }

      it "includes version and company_name in rendered HTML" do
        EventHub::ActorListenerHttp.new(
          port: 8104,
          processor: processor_with_info,
          base_path: "/api"
        )
        sleep 0.2
        uri = URI("http://localhost:8104/api/docs")
        res = Net::HTTP.get_response(uri)

        expect(res.is_a?(Net::HTTPSuccess)).to eq(true)
        expect(res.body).to include("3.0.0")
        expect(res.body).to include("Test Corp")
      end
    end

    context "with custom readme_as_html method" do
      let(:processor_with_custom_readme) {
        Class.new do
          def readme_as_html
            "<h1>Custom README</h1>"
          end
        end.new
      }

      it "uses custom readme_as_html method" do
        EventHub::ActorListenerHttp.new(
          port: 8092,
          processor: processor_with_custom_readme,
          base_path: "/api"
        )
        sleep 0.2
        uri = URI("http://localhost:8092/api/docs")
        res = Net::HTTP.get_response(uri)

        expect(res.is_a?(Net::HTTPSuccess)).to eq(true)
        expect(res.body).to include("<h1>Custom README</h1>")
      end
    end
  end

  describe "changelog endpoint" do
    it "returns HTML with CHANGELOG content" do
      EventHub::ActorListenerHttp.new(
        port: 8093,
        base_path: "/api"
      )
      sleep 0.2
      uri = URI("http://localhost:8093/api/docs/changelog")
      res = Net::HTTP.get_response(uri)

      expect(res.is_a?(Net::HTTPSuccess)).to eq(true)
      expect(res["Content-Type"]).to include("text/html")
      expect(res.body).to include("<!DOCTYPE html>")
      expect(res.body).to include("Changelog")
    end

    context "with custom changelog_as_html method" do
      let(:processor_with_custom_changelog) {
        Class.new do
          def changelog_as_html
            "<h1>Custom CHANGELOG</h1>"
          end
        end.new
      }

      it "uses custom changelog_as_html method" do
        EventHub::ActorListenerHttp.new(
          port: 8094,
          processor: processor_with_custom_changelog,
          base_path: "/api"
        )
        sleep 0.2
        uri = URI("http://localhost:8094/api/docs/changelog")
        res = Net::HTTP.get_response(uri)

        expect(res.is_a?(Net::HTTPSuccess)).to eq(true)
        expect(res.body).to include("<h1>Custom CHANGELOG</h1>")
      end
    end
  end

  describe "assets endpoint" do
    it "serves CSS files" do
      EventHub::ActorListenerHttp.new(
        port: 8095,
        base_path: "/api"
      )
      sleep 0.2
      uri = URI("http://localhost:8095/api/assets/app.css")
      res = Net::HTTP.get_response(uri)

      expect(res.is_a?(Net::HTTPSuccess)).to eq(true)
      expect(res["Content-Type"]).to eq("text/css")
      expect(res.body).to include(".navbar")
    end

    it "serves SVG files" do
      EventHub::ActorListenerHttp.new(
        port: 8096,
        base_path: "/api"
      )
      sleep 0.2
      uri = URI("http://localhost:8096/api/assets/logo.svg")
      res = Net::HTTP.get_response(uri)

      expect(res.is_a?(Net::HTTPSuccess)).to eq(true)
      expect(res["Content-Type"]).to eq("image/svg+xml")
    end

    it "returns 404 for non-existent assets" do
      EventHub::ActorListenerHttp.new(
        port: 8097,
        base_path: "/api"
      )
      sleep 0.2
      uri = URI("http://localhost:8097/api/assets/nonexistent.css")
      res = Net::HTTP.get_response(uri)

      expect(res.is_a?(Net::HTTPNotFound)).to eq(true)
    end

    it "fails with method not allowed for POST" do
      EventHub::ActorListenerHttp.new(
        port: 8098,
        base_path: "/api"
      )
      sleep 0.2
      uri = URI("http://localhost:8098/api/assets/app.css")
      res = Net::HTTP.post(uri, nil)

      expect(res.is_a?(Net::HTTPMethodNotAllowed)).to eq(true)
    end
  end

  describe "docs endpoint POST" do
    it "fails with method not allowed for POST on docs" do
      EventHub::ActorListenerHttp.new(
        port: 8099,
        base_path: "/api"
      )
      sleep 0.2
      uri = URI("http://localhost:8099/api/docs")
      res = Net::HTTP.post(uri, nil)

      expect(res.is_a?(Net::HTTPMethodNotAllowed)).to eq(true)
    end

    it "fails with method not allowed for POST on changelog" do
      EventHub::ActorListenerHttp.new(
        port: 8100,
        base_path: "/api"
      )
      sleep 0.2
      uri = URI("http://localhost:8100/api/docs/changelog")
      res = Net::HTTP.post(uri, nil)

      expect(res.is_a?(Net::HTTPMethodNotAllowed)).to eq(true)
    end
  end

  describe "heartbeat endpoint POST" do
    it "fails with method not allowed for POST on heartbeat" do
      EventHub::ActorListenerHttp.new(
        port: 8101,
        base_path: "/api"
      )
      sleep 0.2
      uri = URI("http://localhost:8101/api/heartbeat")
      res = Net::HTTP.post(uri, nil)

      expect(res.is_a?(Net::HTTPMethodNotAllowed)).to eq(true)
    end
  end

  describe "base path POST" do
    it "fails with method not allowed for POST on base path" do
      EventHub::ActorListenerHttp.new(
        port: 8102,
        base_path: "/api"
      )
      sleep 0.2
      uri = URI("http://localhost:8102/api")
      res = Net::HTTP.post(uri, nil)

      expect(res.is_a?(Net::HTTPMethodNotAllowed)).to eq(true)
    end

    it "fails with method not allowed for POST on base path with trailing slash" do
      EventHub::ActorListenerHttp.new(
        port: 8103,
        base_path: "/api"
      )
      sleep 0.2
      uri = URI("http://localhost:8103/api/")
      res = Net::HTTP.post(uri, nil)

      expect(res.is_a?(Net::HTTPMethodNotAllowed)).to eq(true)
    end
  end
end
