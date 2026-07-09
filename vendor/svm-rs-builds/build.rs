use std::{
    fs::{self, File},
    path::PathBuf,
};

use svm::Releases;

/// The string describing the [`svm::Platform`] to build for.
pub const SVM_TARGET_PLATFORM: &str = "SVM_TARGET_PLATFORM";

/// The path to a pre-fetched releases JSON file.
pub const SVM_RELEASES_LIST_JSON: &str = "SVM_RELEASES_LIST_JSON";

fn get_platform() -> svm::Platform {
    if let Ok(s) = std::env::var(SVM_TARGET_PLATFORM) {
        s.parse().unwrap()
    } else {
        svm::platform()
    }
}

fn output_file() -> PathBuf {
    PathBuf::from(std::env::var("OUT_DIR").expect("OUT_DIR environment variable not set"))
        .join("generated.rs")
}

fn write_release_json(platform: Option<svm::Platform>, release_json: &str) {
    let target_platform = platform.map(|p| p.to_string()).unwrap_or_default();
    let output = format!(
        r##"// Generated file, do not edit by hand

/// The `svm::Platform` all constants were built for.
pub const TARGET_PLATFORM: &str = "{target_platform}";

/// JSON release list.
pub static RELEASE_LIST_JSON: &str = r#"{release_json}"#;
"##
    );

    fs::write(output_file(), output).expect("failed to write output file");
}

fn read_releases_from_file(file_path: String) -> Releases {
    let file = File::open(file_path).unwrap_or_else(|_| {
        panic!("{SVM_RELEASES_LIST_JSON:?} defined, but cannot read the file referenced")
    });

    serde_json::from_reader(file)
        .unwrap_or_else(|_| panic!("Failed to parse the JSON from {SVM_RELEASES_LIST_JSON:?} file"))
}

fn generate() {
    let platform = get_platform();
    let releases = if let Ok(file_path) = std::env::var(SVM_RELEASES_LIST_JSON) {
        Some(read_releases_from_file(file_path))
    } else {
        match svm::blocking_all_releases(platform) {
            Ok(releases) => Some(releases),
            Err(err) => {
                println!(
                    "cargo:warning=failed to fetch static SVM release metadata for {platform}: {err:?}; continuing without compile-time checksum metadata"
                );
                None
            }
        }
    };

    let release_json = releases
        .as_ref()
        .map(serde_json::to_string)
        .transpose()
        .expect("failed to serialize SVM release metadata")
        .unwrap_or_default();

    write_release_json(Some(platform), &release_json);

    println!("cargo:rerun-if-env-changed={SVM_TARGET_PLATFORM}");
    println!("cargo:rerun-if-env-changed={SVM_RELEASES_LIST_JSON}");
}

fn generate_offline() {
    write_release_json(None, "");
}

fn main() {
    #[cfg(not(feature = "_offline"))]
    if std::env::var("DOCS_RS").is_ok() {
        generate_offline();
    } else {
        generate();
    }

    #[cfg(feature = "_offline")]
    generate_offline();
}
