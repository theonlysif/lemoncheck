class Lemoncheck < Formula
  desc "Inspect a used Mac before you buy it — traffic-light lemon detector"
  homepage "https://github.com/theonlysif/lemoncheck"
  url "https://github.com/theonlysif/lemoncheck/archive/refs/tags/v0.1.0.tar.gz"
  version "0.1.0"
  # Replace with the real tarball sha256 once the v0.1.0 tag is published:
  #   curl -sL <url> | shasum -a 256
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"
  license "MIT"
  head "https://github.com/theonlysif/lemoncheck.git", branch: "main"

  # Optional but recommended — enables the full SSD SMART / TBW read.
  depends_on "smartmontools" => :recommended
  # Improves parsing precision.
  depends_on "jq" => :recommended

  def install
    libexec.install "lib"
    bin.install "bin/lemoncheck"
    # Point the launcher at the libexec copy of lib/.
    inreplace bin/"lemoncheck", '[[ -d "$LIB_DIR" ]] || LIB_DIR="$BIN_DIR/../libexec/lib"',
              "LIB_DIR=\"#{libexec}/lib\""
  end

  test do
    assert_match "lemoncheck", shell_output("#{bin}/lemoncheck --version")
    assert_match "Usage", shell_output("#{bin}/lemoncheck --help")
  end
end
