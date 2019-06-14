#include "pch.h"

#include <vcpkg/base/files.h>
#include <vcpkg/base/graphs.h>
#include <vcpkg/base/strings.h>
#include <vcpkg/base/util.h>
#include <vcpkg/dependencies.h>
#include <vcpkg/packagespec.h>
#include <vcpkg/paragraphs.h>
#include <vcpkg/statusparagraphs.h>
#include <vcpkg/vcpkglib.h>
#include <vcpkg/vcpkgpaths.h>

namespace vcpkg::Dependencies
{
    struct ClusterInstalled
    {
        InstalledPackageView ipv;
        std::set<PackageSpec> remove_edges;
        std::set<std::string> original_features;
    };

    struct ClusterSource
    {
        const SourceControlFile* scf = nullptr;
        std::unordered_map<std::string, std::vector<FeatureSpec>> build_edges;
    };

    /// <summary>
    /// Representation of a package and its features in a ClusterGraph.
    /// </summary>
    struct Cluster : Util::MoveOnlyBase
    {
        PackageSpec spec;

        Optional<ClusterInstalled> installed;
        Optional<ClusterSource> source;

        // Note: this map can contain "special" strings such as "" and "*"
        std::unordered_map<std::string, bool> plus;
        std::set<std::string> to_install_features;
        bool minus = false;
        bool transient_uninstalled = true;
        RequestType request_type = RequestType::AUTO_SELECTED;
    };

    struct ClusterPtr
    {
        Cluster* ptr;

        Cluster* operator->() const { return ptr; }
    };

    bool operator==(const ClusterPtr& l, const ClusterPtr& r) { return l.ptr == r.ptr; }
}

namespace std
{
    template<>
    struct hash<vcpkg::Dependencies::ClusterPtr>
    {
        size_t operator()(const vcpkg::Dependencies::ClusterPtr& value) const
        {
            return std::hash<vcpkg::PackageSpec>()(value.ptr->spec);
        }
    };
}

namespace vcpkg::Dependencies
{
    struct GraphPlan
    {
        Graphs::Graph<ClusterPtr> remove_graph;
        Graphs::Graph<ClusterPtr> install_graph;
    };

    /// <summary>
    /// Directional graph representing a collection of packages with their features connected by their dependencies.
    /// </summary>
    struct ClusterGraph : Util::MoveOnlyBase
    {
        explicit ClusterGraph(const PortFileProvider& provider) : m_provider(provider) {}

        /// <summary>
        ///     Find the cluster associated with spec or if not found, create it from the PortFileProvider.
        /// </summary>
        /// <param name="spec">Package spec to get the cluster for.</param>
        /// <returns>The cluster found or created for spec.</returns>
        Cluster& get(const PackageSpec& spec)
        {
            auto it = m_graph.find(spec);
            if (it == m_graph.end())
            {
                // Load on-demand from m_provider
                auto maybe_scf = m_provider.get_control_file(spec.name());
                auto& clust = m_graph[spec];
                clust.spec = spec;
                if (auto p_scf = maybe_scf.get())
                {
                    clust.source = cluster_from_scf(*p_scf, clust.spec.triplet());
                }
                return clust;
            }
            return it->second;
        }

    private:
        static ClusterSource cluster_from_scf(const SourceControlFile& scf, Triplet t)
        {
            ClusterSource ret;
            ret.build_edges.emplace("core", filter_dependencies_to_specs(scf.core_paragraph->depends, t));

            for (const auto& feature : scf.feature_paragraphs)
                ret.build_edges.emplace(feature->name, filter_dependencies_to_specs(feature->depends, t));

            ret.scf = &scf;
            return ret;
        }

        std::unordered_map<PackageSpec, Cluster> m_graph;
        const PortFileProvider& m_provider;
    };

    std::string to_output_string(RequestType request_type,
                                 const CStringView s,
                                 const Build::BuildPackageOptions& options)
    {
        const char* const from_head = options.use_head_version == Build::UseHeadVersion::YES ? " (from HEAD)" : "";

        switch (request_type)
        {
            case RequestType::AUTO_SELECTED: return Strings::format("  * %s%s", s, from_head);
            case RequestType::USER_REQUESTED: return Strings::format("    %s%s", s, from_head);
            default: Checks::unreachable(VCPKG_LINE_INFO);
        }
    }

    std::string to_output_string(RequestType request_type, const CStringView s)
    {
        switch (request_type)
        {
            case RequestType::AUTO_SELECTED: return Strings::format("  * %s", s);
            case RequestType::USER_REQUESTED: return Strings::format("    %s", s);
            default: Checks::unreachable(VCPKG_LINE_INFO);
        }
    }

    InstallPlanAction::InstallPlanAction() noexcept
        : plan_type(InstallPlanType::UNKNOWN), request_type(RequestType::UNKNOWN)
    {
    }

    InstallPlanAction::InstallPlanAction(const PackageSpec& spec,
                                         const SourceControlFile& scf,
                                         Optional<fs::path>&& port_dir,
                                         const std::set<std::string>& features,
                                         const RequestType& request_type,
                                         std::vector<PackageSpec>&& dependencies)
        : spec(spec)
        , feature_list(features)
        , computed_dependencies(std::move(dependencies))
        , plan_type(InstallPlanType::BUILD_AND_INSTALL)
        , request_type(request_type)
        , build_action(BuildAndInstallAction{scf, Build::BuildPackageOptions{}, std::move(port_dir)})
    {
    }

    InstallPlanAction::InstallPlanAction(InstalledPackageView&& ipv,
                                         const std::set<std::string>& features,
                                         const RequestType& request_type)
        : spec(ipv.spec())
        , feature_list(features)
        , computed_dependencies(ipv.dependencies())
        , plan_type(InstallPlanType::ALREADY_INSTALLED)
        , request_type(request_type)
        , installed_package(std::move(ipv))
    {
    }

    std::string InstallPlanAction::displayname() const
    {
        if (this->feature_list.empty())
        {
            return this->spec.to_string();
        }

        const std::string features = Strings::join(",", this->feature_list);
        return Strings::format("%s[%s]:%s", this->spec.name(), features, this->spec.triplet());
    }

    const std::string& InstallPlanAction::version() const
    {
        switch (plan_type){
            case InstallPlanType::ALREADY_INSTALLED:
                return installed_package.value_or_exit(VCPKG_LINE_INFO).core->package.version;
            case InstallPlanType::BUILD_AND_INSTALL:
                return build_action.value_or_exit(VCPKG_LINE_INFO).scf.core_paragraph->version;
            default:
                Checks::unreachable(VCPKG_LINE_INFO);
        }
    }

    std::string InstallPlanAction::nuget_package_version() const
    {
        return Dependencies::nuget_package_version(version(), abi.value_or_exit(VCPKG_LINE_INFO).tag);
    }

    std::string Dependencies::nuget_package_version(const std::string& version, const std::string& abi_tag)
    {
        static const std::regex semver_matcher(R"(v?(\d+\.\d+)(\.(\d+))?.*)");

        std::smatch sm;
        if (std::regex_match(version.cbegin(), version.cend(), sm, semver_matcher))
        {
            if (sm.size() == 2)
                return Strings::concat(sm.str(1), ".0-", abi_tag);
            else if (sm.size() >= 3)
                return Strings::concat(sm.str(1), sm.str(2), "-", abi_tag);
            else
                Checks::unreachable(VCPKG_LINE_INFO);
        }

        return Strings::concat("0.0.0-", abi_tag);
    }

    bool InstallPlanAction::compare_by_name(const InstallPlanAction* left, const InstallPlanAction* right)
    {
        return left->spec.name() < right->spec.name();
    }

    RemovePlanAction::RemovePlanAction() noexcept
        : plan_type(RemovePlanType::UNKNOWN), request_type(RequestType::UNKNOWN)
    {
    }

    RemovePlanAction::RemovePlanAction(const PackageSpec& spec,
                                       const RemovePlanType& plan_type,
                                       const RequestType& request_type)
        : spec(spec), plan_type(plan_type), request_type(request_type)
    {
    }

    const PackageSpec& AnyAction::spec() const
    {
        if (const auto p = install_action.get())
        {
            return p->spec;
        }

        if (const auto p = remove_action.get())
        {
            return p->spec;
        }

        Checks::exit_with_message(VCPKG_LINE_INFO, "Null action");
    }

    bool ExportPlanAction::compare_by_name(const ExportPlanAction* left, const ExportPlanAction* right)
    {
        return left->spec.name() < right->spec.name();
    }

    ExportPlanAction::ExportPlanAction() noexcept
        : plan_type(ExportPlanType::UNKNOWN), request_type(RequestType::UNKNOWN)
    {
    }

    ExportPlanAction::ExportPlanAction(const PackageSpec& spec,
                                       InstalledPackageView&& installed_package,
                                       const RequestType& request_type)
        : spec(spec)
        , plan_type(ExportPlanType::ALREADY_BUILT)
        , request_type(request_type)
        , m_installed_package(std::move(installed_package))
    {
    }

    ExportPlanAction::ExportPlanAction(const PackageSpec& spec, const RequestType& request_type)
        : spec(spec), plan_type(ExportPlanType::NOT_BUILT), request_type(request_type)
    {
    }

    Optional<const BinaryParagraph&> ExportPlanAction::core_paragraph() const
    {
        if (auto p_ip = m_installed_package.get())
        {
            return p_ip->core->package;
        }
        return nullopt;
    }

    std::vector<PackageSpec> ExportPlanAction::dependencies(const Triplet&) const
    {
        if (auto p_ip = m_installed_package.get())
            return p_ip->dependencies();
        else
            return {};
    }

    bool RemovePlanAction::compare_by_name(const RemovePlanAction* left, const RemovePlanAction* right)
    {
        return left->spec.name() < right->spec.name();
    }

    MapPortFileProvider::MapPortFileProvider(const std::unordered_map<std::string, SourceControlFile>& map) : ports(map)
    {
    }

    Optional<const SourceControlFile&> MapPortFileProvider::get_control_file(const std::string& spec) const
    {
        auto scf = ports.find(spec);
        if (scf == ports.end()) return nullopt;
        return scf->second;
    }

    PathsPortFileProvider::PathsPortFileProvider(const VcpkgPaths& paths) : ports(paths) {}

    Optional<const SourceControlFile&> PathsPortFileProvider::get_control_file(const std::string& spec) const
    {
        auto cache_it = cache.find(spec);
        if (cache_it != cache.end())
        {
            return cache_it->second;
        }
        Parse::ParseExpected<SourceControlFile> source_control_file =
            Paragraphs::try_load_port(ports.get_filesystem(), ports.port_dir(spec));

        if (auto scf = source_control_file.get())
        {
            auto it = cache.emplace(spec, std::move(*scf->get()));
            return it.first->second;
        }
        return nullopt;
    }

    std::vector<RemovePlanAction> create_remove_plan(const std::vector<PackageSpec>& specs,
                                                     const StatusParagraphs& status_db)
    {
        struct RemoveAdjacencyProvider final : Graphs::AdjacencyProvider<PackageSpec, RemovePlanAction>
        {
            const StatusParagraphs& status_db;
            const std::vector<InstalledPackageView>& installed_ports;
            const std::unordered_set<PackageSpec>& specs_as_set;

            RemoveAdjacencyProvider(const StatusParagraphs& status_db,
                                    const std::vector<InstalledPackageView>& installed_ports,
                                    const std::unordered_set<PackageSpec>& specs_as_set)
                : status_db(status_db), installed_ports(installed_ports), specs_as_set(specs_as_set)
            {
            }

            std::vector<PackageSpec> adjacency_list(const RemovePlanAction& plan) const override
            {
                if (plan.plan_type == RemovePlanType::NOT_INSTALLED)
                {
                    return {};
                }

                const PackageSpec& spec = plan.spec;
                std::vector<PackageSpec> dependents;
                for (auto&& ipv : installed_ports)
                {
                    auto deps = ipv.dependencies();

                    if (std::find(deps.begin(), deps.end(), spec) == deps.end()) continue;

                    dependents.push_back(ipv.spec());
                }

                return dependents;
            }

            RemovePlanAction load_vertex_data(const PackageSpec& spec) const override
            {
                const RequestType request_type = specs_as_set.find(spec) != specs_as_set.end()
                                                     ? RequestType::USER_REQUESTED
                                                     : RequestType::AUTO_SELECTED;
                const StatusParagraphs::const_iterator it = status_db.find_installed(spec);
                if (it == status_db.end())
                {
                    return RemovePlanAction{spec, RemovePlanType::NOT_INSTALLED, request_type};
                }
                return RemovePlanAction{spec, RemovePlanType::REMOVE, request_type};
            }

            std::string to_string(const PackageSpec& spec) const override { return spec.to_string(); }
        };

        auto installed_ports = get_installed_ports(status_db);
        const std::unordered_set<PackageSpec> specs_as_set(specs.cbegin(), specs.cend());
        return Graphs::topological_sort(specs, RemoveAdjacencyProvider{status_db, installed_ports, specs_as_set}, {});
    }

    std::vector<ExportPlanAction> create_export_plan(const std::vector<PackageSpec>& specs,
                                                     const StatusParagraphs& status_db)
    {
        struct ExportAdjacencyProvider final : Graphs::AdjacencyProvider<PackageSpec, ExportPlanAction>
        {
            const StatusParagraphs& status_db;
            const std::unordered_set<PackageSpec>& specs_as_set;

            ExportAdjacencyProvider(const StatusParagraphs& s, const std::unordered_set<PackageSpec>& specs_as_set)
                : status_db(s), specs_as_set(specs_as_set)
            {
            }

            std::vector<PackageSpec> adjacency_list(const ExportPlanAction& plan) const override
            {
                return plan.dependencies(plan.spec.triplet());
            }

            ExportPlanAction load_vertex_data(const PackageSpec& spec) const override
            {
                const RequestType request_type = specs_as_set.find(spec) != specs_as_set.end()
                                                     ? RequestType::USER_REQUESTED
                                                     : RequestType::AUTO_SELECTED;

                auto maybe_ipv = status_db.find_all_installed(spec);

                if (auto p_ipv = maybe_ipv.get())
                {
                    return ExportPlanAction{spec, std::move(*p_ipv), request_type};
                }

                return ExportPlanAction{spec, request_type};
            }

            std::string to_string(const PackageSpec& spec) const override { return spec.to_string(); }
        };

        const std::unordered_set<PackageSpec> specs_as_set(specs.cbegin(), specs.cend());
        std::vector<ExportPlanAction> toposort =
            Graphs::topological_sort(specs, ExportAdjacencyProvider{status_db, specs_as_set}, {});
        return toposort;
    }

    enum class MarkPlusResult
    {
        FEATURE_NOT_FOUND,
        SUCCESS,
    };

    static MarkPlusResult mark_plus(const std::string& feature,
                                    Cluster& cluster,
                                    ClusterGraph& graph,
                                    GraphPlan& graph_plan,
                                    const std::unordered_set<std::string>& prevent_default_features);

    static void mark_minus(Cluster& cluster,
                           ClusterGraph& graph,
                           GraphPlan& graph_plan,
                           const std::unordered_set<std::string>& prevent_default_features);

    static MarkPlusResult follow_plus_dependencies(const std::string& feature,
                                                   Cluster& cluster,
                                                   ClusterGraph& graph,
                                                   GraphPlan& graph_plan,
                                                   const std::unordered_set<std::string>& prevent_default_features)
    {
        if (auto p_source = cluster.source.get())
        {
            auto it_build_edges = p_source->build_edges.find(feature);
            if (it_build_edges != p_source->build_edges.end())
            {
                // mark this package for rebuilding if needed
                mark_minus(cluster, graph, graph_plan, prevent_default_features);

                graph_plan.install_graph.add_vertex({&cluster});
                cluster.to_install_features.insert(feature);

                if (feature != "core")
                {
                    // All features implicitly depend on core
                    auto res = mark_plus("core", cluster, graph, graph_plan, prevent_default_features);

                    // Should be impossible for "core" to not exist
                    Checks::check_exit(VCPKG_LINE_INFO, res == MarkPlusResult::SUCCESS);
                }

                if (!cluster.installed.get() && !Util::Sets::contains(prevent_default_features, cluster.spec.name()))
                {
                    // Add the default features of this package if it was not previously installed and it isn't being
                    // suppressed.
                    auto res = mark_plus("", cluster, graph, graph_plan, prevent_default_features);

                    Checks::check_exit(VCPKG_LINE_INFO,
                                       res == MarkPlusResult::SUCCESS,
                                       "Error: Unable to satisfy default dependencies of %s",
                                       cluster.spec);
                }

                for (auto&& depend : it_build_edges->second)
                {
                    auto& depend_cluster = graph.get(depend.spec());
                    auto res = mark_plus(depend.feature(), depend_cluster, graph, graph_plan, prevent_default_features);

                    Checks::check_exit(VCPKG_LINE_INFO,
                                       res == MarkPlusResult::SUCCESS,
                                       "Error: Unable to satisfy dependency %s of %s",
                                       depend,
                                       FeatureSpec(cluster.spec, feature));

                    if (&depend_cluster == &cluster) continue;
                    graph_plan.install_graph.add_edge({&cluster}, {&depend_cluster});
                }

                return MarkPlusResult::SUCCESS;
            }
        }

        // The feature was not available in the installed package nor the source paragraph.
        return MarkPlusResult::FEATURE_NOT_FOUND;
    }

    MarkPlusResult mark_plus(const std::string& feature,
                             Cluster& cluster,
                             ClusterGraph& graph,
                             GraphPlan& graph_plan,
                             const std::unordered_set<std::string>& prevent_default_features)
    {
        auto& plus = cluster.plus[feature];
        if (plus) return MarkPlusResult::SUCCESS;
        plus = true;

        auto p_source = cluster.source.get();
        Checks::check_exit(VCPKG_LINE_INFO,
                           p_source != nullptr,
                           "Error: Cannot find definition for package `%s`.",
                           cluster.spec.name());

        if (feature.empty())
        {
            // Add default features for this package. This is an exact reference, so ignore prevent_default_features.
            for (auto&& default_feature : p_source->scf->core_paragraph.get()->default_features)
            {
                auto res = mark_plus(default_feature, cluster, graph, graph_plan, prevent_default_features);
                if (res != MarkPlusResult::SUCCESS)
                {
                    return res;
                }
            }

            // "core" is always required.
            return mark_plus("core", cluster, graph, graph_plan, prevent_default_features);
        }

        if (feature == "*")
        {
            for (auto&& fpgh : p_source->scf->feature_paragraphs)
            {
                auto res = mark_plus(fpgh->name, cluster, graph, graph_plan, prevent_default_features);

                Checks::check_exit(VCPKG_LINE_INFO,
                                   res == MarkPlusResult::SUCCESS,
                                   "Error: Internal error while installing feature %s in %s",
                                   fpgh->name,
                                   cluster.spec);
            }

            auto res = mark_plus("core", cluster, graph, graph_plan, prevent_default_features);

            Checks::check_exit(VCPKG_LINE_INFO, res == MarkPlusResult::SUCCESS);
            return MarkPlusResult::SUCCESS;
        }

        if (auto p_installed = cluster.installed.get())
        {
            if (p_installed->original_features.find(feature) != p_installed->original_features.end())
            {
                return MarkPlusResult::SUCCESS;
            }
        }

        // This feature was or will be uninstalled, therefore we need to rebuild
        mark_minus(cluster, graph, graph_plan, prevent_default_features);

        return follow_plus_dependencies(feature, cluster, graph, graph_plan, prevent_default_features);
    }

    void mark_minus(Cluster& cluster,
                    ClusterGraph& graph,
                    GraphPlan& graph_plan,
                    const std::unordered_set<std::string>& prevent_default_features)
    {
        if (cluster.minus) return;
        cluster.minus = true;
        cluster.transient_uninstalled = true;

        auto p_installed = cluster.installed.get();
        auto p_source = cluster.source.get();

        Checks::check_exit(
            VCPKG_LINE_INFO,
            p_source,
            "Error: cannot locate new portfile for %s. Please explicitly remove this package with `vcpkg remove %s`.",
            cluster.spec,
            cluster.spec);

        if (p_installed)
        {
            graph_plan.remove_graph.add_vertex({&cluster});
            for (auto&& edge : p_installed->remove_edges)
            {
                auto& depend_cluster = graph.get(edge);
                Checks::check_exit(VCPKG_LINE_INFO, &cluster != &depend_cluster);
                graph_plan.remove_graph.add_edge({&cluster}, {&depend_cluster});
                mark_minus(depend_cluster, graph, graph_plan, prevent_default_features);
            }

            // Reinstall all original features. Don't use mark_plus because it will ignore them since they are
            // "already installed".
            for (auto&& f : p_installed->original_features)
            {
                auto res = follow_plus_dependencies(f, cluster, graph, graph_plan, prevent_default_features);
                if (res != MarkPlusResult::SUCCESS)
                {
                    System::print2(System::Color::warning,
                                   "Warning: could not reinstall feature ",
                                   FeatureSpec{cluster.spec, f},
                                   "\n");
                }
            }

            // Check if any default features have been added
            auto& previous_df = p_installed->ipv.core->package.default_features;
            for (auto&& default_feature : p_source->scf->core_paragraph->default_features)
            {
                if (std::find(previous_df.begin(), previous_df.end(), default_feature) == previous_df.end())
                {
                    // This is a new default feature, mark it for installation
                    auto res = mark_plus(default_feature, cluster, graph, graph_plan, prevent_default_features);
                    if (res != MarkPlusResult::SUCCESS)
                    {
                        System::print2(System::Color::warning,
                                       "Warning: could not install new default feature ",
                                       FeatureSpec{cluster.spec, default_feature},
                                       "\n");
                    }
                }
            }
        }
    }

    std::vector<AnyAction> create_feature_install_plan(const PortFileProvider& provider,
                                                       const std::vector<FeatureSpec>& specs,
                                                       const StatusParagraphs& status_db,
                                                       const CreateInstallPlanOptions& options)
    {
        std::unordered_set<std::string> prevent_default_features;
        for (auto&& spec : specs)
        {
            // When "core" is explicitly listed, default features should not be installed.
            if (spec.feature() == "core") prevent_default_features.insert(spec.name());
        }

        PackageGraph pgraph(provider, status_db);
        for (auto&& spec : specs)
        {
            // If preventing default features, ignore the automatically generated "" references
            if (spec.feature().empty() && Util::Sets::contains(prevent_default_features, spec.name())) continue;
            pgraph.install(spec, prevent_default_features);
        }

        return pgraph.serialize(options);
    }

    /// <summary>Figure out which actions are required to install features specifications in `specs`.</summary>
    /// <param name="map">Map of all source control files in the current environment.</param>
    /// <param name="specs">Feature specifications to resolve dependencies for.</param>
    /// <param name="status_db">Status of installed packages in the current environment.</param>
    std::vector<AnyAction> create_feature_install_plan(const std::unordered_map<std::string, SourceControlFile>& map,
                                                       const std::vector<FeatureSpec>& specs,
                                                       const StatusParagraphs& status_db)
    {
        MapPortFileProvider provider(map);
        return create_feature_install_plan(provider, specs, status_db);
    }

    /// <param name="prevent_default_features">
    /// List of package names for which default features should not be installed instead of the core package (e.g. if
    /// the user is currently installing specific features of that package).
    /// </param>
    void PackageGraph::install(const FeatureSpec& spec,
                               const std::unordered_set<std::string>& prevent_default_features) const
    {
        Cluster& spec_cluster = m_graph->get(spec.spec());
        spec_cluster.request_type = RequestType::USER_REQUESTED;

        auto res = mark_plus(spec.feature(), spec_cluster, *m_graph, *m_graph_plan, prevent_default_features);

        Checks::check_exit(VCPKG_LINE_INFO,
                           res == MarkPlusResult::SUCCESS,
                           "Error: `%s` is not a feature of package `%s`",
                           spec.feature(),
                           spec.name());

        m_graph_plan->install_graph.add_vertex(ClusterPtr{&spec_cluster});
    }

    void PackageGraph::upgrade(const PackageSpec& spec) const
    {
        Cluster& spec_cluster = m_graph->get(spec);
        spec_cluster.request_type = RequestType::USER_REQUESTED;

        mark_minus(spec_cluster, *m_graph, *m_graph_plan, {});
    }

    std::vector<AnyAction> PackageGraph::serialize(const CreateInstallPlanOptions& options) const
    {
        auto remove_vertex_list = m_graph_plan->remove_graph.vertex_list();
        auto remove_toposort =
            Graphs::topological_sort(remove_vertex_list, m_graph_plan->remove_graph, options.randomizer);

        auto insert_vertex_list = m_graph_plan->install_graph.vertex_list();
        auto insert_toposort =
            Graphs::topological_sort(insert_vertex_list, m_graph_plan->install_graph, options.randomizer);

        std::vector<AnyAction> plan;

        for (auto&& p_cluster : remove_toposort)
        {
            plan.emplace_back(RemovePlanAction{
                std::move(p_cluster->spec),
                RemovePlanType::REMOVE,
                p_cluster->request_type,
            });
        }

        for (auto&& p_cluster : insert_toposort)
        {
            if (p_cluster->transient_uninstalled)
            {
                // If it will be transiently uninstalled, we need to issue a full installation command
                auto pscf = p_cluster->source.value_or_exit(VCPKG_LINE_INFO).scf;

                auto dep_specs = Util::fmap(m_graph_plan->install_graph.adjacency_list(p_cluster),
                                            [](ClusterPtr const& p) { return p->spec; });
                Util::sort_unique_erase(dep_specs);

                plan.emplace_back(InstallPlanAction{
                    p_cluster->spec,
                    *pscf,
                    {},
                    p_cluster->to_install_features,
                    p_cluster->request_type,
                    std::move(dep_specs),
                });
            }
            else
            {
                // If the package isn't transitively installed, still include it if the user explicitly requested it
                if (p_cluster->request_type != RequestType::USER_REQUESTED) continue;
                auto&& installed = p_cluster->installed.value_or_exit(VCPKG_LINE_INFO);
                plan.emplace_back(InstallPlanAction{
                    InstalledPackageView{installed.ipv},
                    installed.original_features,
                    p_cluster->request_type,
                });
            }
        }

        return plan;
    }

    static std::unique_ptr<ClusterGraph> create_feature_install_graph(const PortFileProvider& map,
                                                                      const StatusParagraphs& status_db)
    {
        std::unique_ptr<ClusterGraph> graph = std::make_unique<ClusterGraph>(map);

        auto installed_ports = get_installed_ports(status_db);

        for (auto&& ipv : installed_ports)
        {
            Cluster& cluster = graph->get(ipv.spec());

            cluster.transient_uninstalled = false;

            cluster.installed = [](const InstalledPackageView& ipv) -> ClusterInstalled {
                ClusterInstalled ret;
                ret.ipv = ipv;
                ret.original_features.emplace("core");
                for (auto&& feature : ipv.features)
                    ret.original_features.emplace(feature->package.feature);
                return ret;
            }(ipv);
        }

        // Populate the graph with "remove edges", which are the reverse of the Build-Depends edges.
        for (auto&& ipv : installed_ports)
        {
            auto deps = ipv.dependencies();

            for (auto&& dep : deps)
            {
                auto p_installed = graph->get(dep).installed.get();
                Checks::check_exit(VCPKG_LINE_INFO,
                                   p_installed,
                                   "Error: database corrupted. Package %s is installed but dependency %s is not.",
                                   ipv.spec(),
                                   dep);
                p_installed->remove_edges.emplace(ipv.spec());
            }
        }
        return graph;
    }

    PackageGraph::PackageGraph(const PortFileProvider& provider, const StatusParagraphs& status_db)
        : m_graph_plan(std::make_unique<GraphPlan>()), m_graph(create_feature_install_graph(provider, status_db))
    {
    }

    PackageGraph::~PackageGraph() = default;

    void print_plan(const std::vector<AnyAction>& action_plan, const bool is_recursive)
    {
        std::vector<const RemovePlanAction*> remove_plans;
        std::vector<const InstallPlanAction*> rebuilt_plans;
        std::vector<const InstallPlanAction*> only_install_plans;
        std::vector<const InstallPlanAction*> new_plans;
        std::vector<const InstallPlanAction*> already_installed_plans;
        std::vector<const InstallPlanAction*> excluded;

        const bool has_non_user_requested_packages = Util::find_if(action_plan, [](const AnyAction& package) -> bool {
                                                         if (auto iplan = package.install_action.get())
                                                             return iplan->request_type != RequestType::USER_REQUESTED;
                                                         else
                                                             return false;
                                                     }) != action_plan.cend();

        for (auto&& action : action_plan)
        {
            if (auto install_action = action.install_action.get())
            {
                // remove plans are guaranteed to come before install plans, so we know the plan will be contained if at
                // all.
                auto it = Util::find_if(
                    remove_plans, [&](const RemovePlanAction* plan) { return plan->spec == install_action->spec; });
                if (it != remove_plans.end())
                {
                    rebuilt_plans.emplace_back(install_action);
                }
                else
                {
                    switch (install_action->plan_type)
                    {
                        case InstallPlanType::ALREADY_INSTALLED:
                            if (install_action->request_type == RequestType::USER_REQUESTED)
                                already_installed_plans.emplace_back(install_action);
                            break;
                        case InstallPlanType::BUILD_AND_INSTALL: new_plans.emplace_back(install_action); break;
                        case InstallPlanType::EXCLUDED: excluded.emplace_back(install_action); break;
                        default: Checks::unreachable(VCPKG_LINE_INFO);
                    }
                }
            }
            else if (auto remove_action = action.remove_action.get())
            {
                remove_plans.emplace_back(remove_action);
            }
        }

        std::sort(remove_plans.begin(), remove_plans.end(), &RemovePlanAction::compare_by_name);
        std::sort(rebuilt_plans.begin(), rebuilt_plans.end(), &InstallPlanAction::compare_by_name);
        std::sort(only_install_plans.begin(), only_install_plans.end(), &InstallPlanAction::compare_by_name);
        std::sort(new_plans.begin(), new_plans.end(), &InstallPlanAction::compare_by_name);
        std::sort(already_installed_plans.begin(), already_installed_plans.end(), &InstallPlanAction::compare_by_name);
        std::sort(excluded.begin(), excluded.end(), &InstallPlanAction::compare_by_name);

        static auto actions_to_output_string = [](const std::vector<const InstallPlanAction*>& v) {
            return Strings::join("\n", v, [](const InstallPlanAction* p) {
                if (auto build_action = p->build_action.get())
                    return to_output_string(p->request_type, p->displayname(), build_action->build_options);
                else
                    return to_output_string(p->request_type, p->displayname(), {});
            });
        };

        if (!excluded.empty())
        {
            System::print2("The following packages are excluded:\n", actions_to_output_string(excluded), '\n');
        }

        if (!already_installed_plans.empty())
        {
            System::print2("The following packages are already installed:\n",
                           actions_to_output_string(already_installed_plans),
                           '\n');
        }

        if (!rebuilt_plans.empty())
        {
            System::print2("The following packages will be rebuilt:\n", actions_to_output_string(rebuilt_plans), '\n');
        }

        if (!new_plans.empty())
        {
            System::print2(
                "The following packages will be built and installed:\n", actions_to_output_string(new_plans), '\n');
        }

        if (!only_install_plans.empty())
        {
            System::print2("The following packages will be directly installed:\n",
                           actions_to_output_string(only_install_plans),
                           '\n');
        }

        if (has_non_user_requested_packages)
            System::print2("Additional packages (*) will be modified to complete this operation.\n");

        if (!remove_plans.empty() && !is_recursive)
        {
            System::print2(System::Color::warning,
                           "If you are sure you want to rebuild the above packages, run the command with the "
                           "--recurse option\n");
            Checks::exit_fail(VCPKG_LINE_INFO);
        }
    }
}
