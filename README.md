# Pipes Mod for Flowpipe

Pipes pipeline library for [Flowpipe](https://flowpipe.io), enabling seamless integration of Pipes services into your workflows.

## Documentation

- **[Pipelines →](https://hub.flowpipe.io/mods/turbot/pipes/pipelines)**

## Getting Started

### Requirements

Docker daemon must be installed and running. Please see [Install Docker Engine](https://docs.docker.com/engine/install/) for more information.

### Installation

Download and install Flowpipe (https://flowpipe.io/downloads). Or use Brew:

```sh
brew tap turbot/tap
brew install flowpipe
```

Clone:

```sh
git clone https://github.com/turbot/flowpipe-mod-pipes.git
cd flowpipe-mod-pipes
```

### Credentials

By default, the following environment variables will be used for authentication:

- `PIPES_TOKEN`

You can also create `credential` resources in configuration files:

```sh
vi ~/.flowpipe/config/pipes.fpc
```

```hcl
credential "pipes" "my_pipes" {
  token = "tpt_cld630jSCGU4yre79890csdjch79"
}
```

For more information on credentials in Flowpipe, please see [Managing Credentials](https://flowpipe.io/docs/run/credentials).

### Usage

List pipelines:

```sh
flowpipe pipeline list
```

Run a pipeline:

```sh
flowpipe pipeline run get_user --arg user_handle='turbot'
```

You can pass in pipeline arguments as well:

```sh
flowpipe pipeline run get_organization_member --arg user_handle='turbot' --arg org_handle='turbot'
```

To use a specific `credential`, specify the `cred` pipeline argument:

```sh
flowpipe pipeline run get_user --arg user_handle='turbot' --arg cred=my_pipes
```

For more examples on how you can run pipelines, please see [Run Pipelines](https://flowpipe.io/docs/run/pipelines).

### Configuration

No additional configuration is required.

## Contributing

If you have an idea for additional pipelines or just want to help maintain and extend this mod ([or others](https://github.com/topics/flowpipe-mod)) we would love you to join the community and start contributing.

- **[Join #flowpipe in our Slack community](https://flowpipe.io/community/join)**

Please see the [contribution guidelines](https://github.com/turbot/flowpipe/blob/main/CONTRIBUTING.md) and our [code of conduct](https://github.com/turbot/flowpipe/blob/main/CODE_OF_CONDUCT.md).

Want to help but not sure where to start? Pick up one of the `help wanted` issues:

- [Flowpipe](https://github.com/turbot/flowpipe/labels/help%20wanted)
- [Pipes Mod](https://github.com/turbot/flowpipe-mod-pipes/labels/help%20wanted)

## License

This mod is licensed under the [Apache License 2.0](https://github.com/turbot/flowpipe-mod-pipes/blob/main/LICENSE).

Flowpipe is licensed under the [AGPLv3](https://github.com/turbot/flowpipe/blob/main/LICENSE).
