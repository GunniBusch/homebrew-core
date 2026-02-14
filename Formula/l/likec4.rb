class Likec4 < Formula
  desc "Architecture modeling tool with live diagrams from code"
  homepage "https://likec4.dev"
  url "https://registry.npmjs.org/likec4/-/likec4-1.49.0.tgz"
  sha256 "2ab93034bfd1684f1fae8655a751c56dc0fbc53f4e1e27e1d3391292a4dafefb"
  license "MIT"

  depends_on "pnpm" => :build
  depends_on "node"
  depends_on "graphviz"

  def install
    system "npm", "install", *std_npm_args
    bin.install_symlink libexec.glob("bin/*")

    deuniversalize_machos if OS.mac?

    generate_completions_from_executable(bin/"likec4", "completion", shells: [:bash, :zsh])
  end

  test do
    (testpath/"test.c4").write <<~C4
      specification {
        element system
        element component
      }
      model {
        sys = system 'Test System' {
          api = component 'API'
          db = component 'Database'
        }
        api -> db 'queries'
      }
      views {
        view index {
          include *
        }
      }
    C4

    system bin/"likec4", "validate", testpath
    assert_match version.to_s, shell_output("#{bin}/likec4 --version")

    system bin/"likec4", "export", "json", "-o", testpath/"output.json", testpath
    assert_path_exists testpath/"output.json"
    json_output = JSON.parse((testpath/"output.json").read)
    assert json_output.key?("views"), "Expected JSON export to contain views"
    assert json_output.key?("elements"), "Expected JSON export to contain elements"

    system bin/"likec4", "gen", "mermaid", "-o", testpath/"output", testpath
    assert_path_exists testpath/"output"
    mermaid_files = Dir[testpath/"output/**/*.mmd"]
    assert mermaid_files.any?, "Expected at least one .mmd file to be generated"
  end
end
