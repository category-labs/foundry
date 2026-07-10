<!-- Remove this transitional notice after the v1.7.1-monad-v1.0.0 migration window. -->

> [!IMPORTANT]
> Existing Monad `foundryup` installations using the legacy `1.5.0` version must reinstall the
> launcher once:
>
> ```sh
> curl -L https://raw.githubusercontent.com/category-labs/foundry/monad/foundryup/install | bash
> ```
>
> The legacy updater only understands `major.minor.patch` versions and cannot self-update to the
> new `1.5.0-monad-v1.0.0` version scheme. After this one-time reinstall, future launcher updates
> can use `foundryup --update` again.
