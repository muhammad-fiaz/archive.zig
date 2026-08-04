<script setup>
import { useRoute } from 'vitepress'
import { computed } from 'vue'

const route = useRoute()

const breadcrumbs = computed(() => {
  const parts = route.path.replace(/^\/archive\.zig\//, '').replace(/\/$/, '').split('/').filter(Boolean)
  const items = [{ name: 'Home', path: '/archive.zig/' }]
  
  let currentPath = '/archive.zig'
  for (let i = 0; i < parts.length; i++) {
    currentPath += '/' + parts[i]
    const name = parts[i]
      .replace(/\.md$/, '')
      .split('-')
      .map(s => s.charAt(0).toUpperCase() + s.slice(1))
      .join(' ')
    
    items.push({
      name,
      path: i === parts.length - 1 ? null : currentPath + '/',
    })
  }
  
  return items
})
</script>

<template>
  <nav v-if="breadcrumbs.length > 1" class="breadcrumbs" aria-label="Breadcrumb">
    <ol>
      <li v-for="(crumb, index) in breadcrumbs" :key="index">
        <a v-if="crumb.path" :href="crumb.path">{{ crumb.name }}</a>
        <span v-else aria-current="page">{{ crumb.name }}</span>
        <span v-if="index < breadcrumbs.length - 1" class="separator" aria-hidden="true">/</span>
      </li>
    </ol>
  </nav>
</template>

<style scoped>
.breadcrumbs {
  padding: 0.5rem 0;
  margin-bottom: 1rem;
  border-bottom: 1px solid var(--vp-c-divider);
  font-size: 0.875rem;
}

.breadcrumbs ol {
  list-style: none;
  margin: 0;
  padding: 0;
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 0.25rem;
}

.breadcrumbs li {
  display: inline-flex;
  align-items: center;
}

.breadcrumbs a {
  color: var(--vp-c-brand-1);
  text-decoration: none;
  transition: color 0.2s;
}

.breadcrumbs a:hover {
  color: var(--vp-c-brand-2);
  text-decoration: underline;
}

.breadcrumbs span[aria-current="page"] {
  color: var(--vp-c-text-2);
  font-weight: 500;
}

.breadcrumbs .separator {
  color: var(--vp-c-text-3);
  margin: 0 0.125rem;
  font-size: 0.8em;
}
</style>
