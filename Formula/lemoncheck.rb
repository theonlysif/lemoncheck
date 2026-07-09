class Lemoncheck < Formula
  desc "Inspect a used Mac before you buy it — traffic-light lemon detector"
  homepage "https://github.com/theonlysif/lemoncheck"
  url "https://github.com/theonlysif/lemoncheck/archive/refs/tags/v0.1.1.tar.gz"
  sha256 "5526e02bc44e7bb12d3c78a1f820b387a15b91460eb2c79829bc5381f6120218"
  license "MIT"
  head "https://github.com/theonlysif/lemoncheck.git", branch: "main"

  # Improves parsing precision.
  depends_on "jq" => :recommended
  # Optional but recommended — enables the full SSD SMART / TBW read.
  depends_on "smartmontools" => :recommended

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
