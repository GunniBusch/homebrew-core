class Pgroll < Formula
  desc "Postgres zero-downtime migrations made easy"
  homepage "https://pgroll.com"
  url "https://github.com/xataio/pgroll/archive/refs/tags/v0.16.0.tar.gz"
  sha256 "6454f2fda2f82f0b6ddd1904b3562275fb629794a8770efa5c0e97d1fc220d2d"
  license "Apache-2.0"

  depends_on "go" => :build
  depends_on "postgresql@17" => :test

  resource "example-migration" do
      url "https://raw.githubusercontent.com/xataio/pgroll/refs/tags/v0.16.0/examples/01_create_tables.yaml"
      sha256 "d7d5e3d3f8ddbc59933073357db3302227e5f277c9810b945cda3e63f35a8da9"
  end

  def install
    ENV["CGO_ENABLED"] = "1"
    ldflags = %W[
      -s -w
      -X github.com/xataio/pgroll/cmd.Version=#{version}
    ]
    system "go", "build", *std_go_args(ldflags:)
    generate_completions_from_executable(bin/"pgroll", shell_parameter_format: :cobra)
  end

  test do
    user = ENV["USER"]
    ENV["LC_ALL"] = "C"

    port = free_port
    data_dir = testpath/"data"
    pg_uri = "postgres://#{user}@localhost:#{port}/postgres?sslmode=disable"

    system Formula["postgresql@17"].opt_bin/"initdb", "-D", data_dir
    (data_dir/"postgresql.conf").write <<~EOS, mode: "a+"

      port = #{port}
    EOS

    system Formula["postgresql@17"].opt_bin/"pg_ctl", "start", "-D", data_dir, "-l", testpath/"logfile"
    assert_match version.to_s, shell_output("#{bin}/pgroll --version")

    begin
       system bin/"pgroll", "init", "--postgres-url", pg_uri
       resource("example-migration").stage do
          system bin/"pgroll", "--postgres-url", pg_uri, "start", "01_create_tables.yaml"
       end

       status_output = shell_output("#{bin}/pgroll --postgres-url #{pg_uri} status")
       assert_match "01_create_tables", status_output

       complete_output = shell_output("#{bin}/pgroll --postgres-url #{pg_uri} complete 2>&1")
       assert_match "Migration successful", complete_output
    ensure
      system Formula["postgresql@17"].opt_bin/"pg_ctl", "-D", data_dir, "-m", "fast", "stop"
    end
  end
end
