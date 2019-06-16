#include "pch.h"

#include <future>
#include <mutex>
#include <vcpkg/base/checks.h>
#include <vcpkg/base/system.debug.h>
#include <vcpkg/base/system.jobs.h>
#include <vector>

namespace vcpkg::System
{
    namespace Jobs
    {
        struct Queue
        {
            std::mutex m_lock;
            std::vector<std::future<void>> m_futures;
            std::vector<std::string> m_descriptions;
            std::vector<bool> m_completions;
            bool m_join_all_in_progress = false;
        };

        static Queue& get_global_jobs_queue()
        {
            // This queue will leak.
            static Queue* s_queue = new Queue();
            return *s_queue;
        }
    }

    void Jobs::post(std::function<void()>&& f, std::string&& description)
    {
        auto& q = get_global_jobs_queue();
        std::lock_guard<std::mutex> lk(q.m_lock);
        if (q.m_join_all_in_progress)
            Checks::exit_with_message(VCPKG_LINE_INFO, "Attempted to post job to queue while draining.");
        q.m_descriptions.push_back(std::move(description));
        q.m_completions.push_back(false);
        q.m_futures.push_back(std::async(
            [](std::function<void()>& f, size_t i) {
                f();
                auto& q = get_global_jobs_queue();
                std::lock_guard<std::mutex> lk(q.m_lock);
                if (!q.m_join_all_in_progress) q.m_completions[i] = true;
            },
            std::move(f),
            q.m_futures.size()));
    }

    void Jobs::join_all()
    {
        auto& q = get_global_jobs_queue();
        {
            std::lock_guard<std::mutex> lk(q.m_lock);
            if (q.m_join_all_in_progress)
                Checks::exit_with_message(VCPKG_LINE_INFO, "Attempted to drain queue while draining.");
            q.m_join_all_in_progress = true;
        }

        for (size_t i = 0; i < q.m_futures.size(); ++i)
        {
            if (q.m_completions[i])
                Debug::print("Waiting for background task: ", q.m_descriptions[i], '\n');
            else
                System::print2("Waiting for background task: ", q.m_descriptions[i], '\n');

            q.m_futures[i].get();
        }

        {
            std::lock_guard<std::mutex> lk(q.m_lock);
            q.m_join_all_in_progress = false;
            q.m_futures.clear();
            q.m_descriptions.clear();
            q.m_completions.clear();
        }
    }
}
