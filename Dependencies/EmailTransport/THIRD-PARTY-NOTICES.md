# Email transport third-party notices

The e-mail transport dependency set is restored only from the official NuGet
v3 flat-container source declared in `dependency-manifest.json`. Every package
and deployed DLL is pinned by SHA-256.

| Package | Version | Runtime asset | License |
| --- | ---: | --- | --- |
| MailKit | 4.18.0 | `lib/net48/MailKit.dll` | MIT |
| MimeKit | 4.18.0 | `lib/net48/MimeKit.dll` | MIT |
| BouncyCastle.Cryptography | 2.7.0 | `lib/net461/BouncyCastle.Cryptography.dll` | MIT |
| System.Formats.Asn1 | 10.0.0 | `lib/net462/System.Formats.Asn1.dll` | MIT |
| System.Buffers | 4.6.1 | `lib/net462/System.Buffers.dll` | MIT |
| System.Memory | 4.6.3 | `lib/net462/System.Memory.dll` | MIT |
| System.Threading.Tasks.Extensions | 4.6.3 | `lib/net462/System.Threading.Tasks.Extensions.dll` | MIT |
| System.Numerics.Vectors | 4.6.1 | `lib/net462/System.Numerics.Vectors.dll` | MIT |
| System.Runtime.CompilerServices.Unsafe | 6.1.2 | `lib/net462/System.Runtime.CompilerServices.Unsafe.dll` | MIT |
| System.ValueTuple | 4.6.1 | Framework inbox on .NET Framework 4.8; no DLL deployed | MIT |

The common MIT license text is stored in `LICENSES/MIT.txt`. Copyright notices
remain available inside each immutable NuGet package referenced by the
manifest. The Microsoft packages may also carry third-party notices inside
their original packages; the restore process does not remove or rewrite those
packages in its temporary verification cache.

Primary projects and package metadata:

- <https://www.nuget.org/packages/MailKit/4.18.0>
- <https://www.nuget.org/packages/MimeKit/4.18.0>
- <https://github.com/jstedfast/MailKit>
- <https://github.com/jstedfast/MimeKit>
